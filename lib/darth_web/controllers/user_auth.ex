defmodule DarthWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Darth.Controller.Asset
  alias Darth.Controller.User
  alias Darth.Model.User, as: UserStruct
  alias DarthWeb.Router.Helpers, as: Routes

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  max_age_in_seconds = Application.compile_env!(:darth, :max_age_in_seconds)
  @remember_me_options [sign: true, max_age_in_seconds: max_age_in_seconds, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def login_user(conn, user, params \\ %{}) do
    token = User.generate_user_token(user, "session")
    user_return_to = get_session(conn, :user_return_to)

    case User.record_login(user) do
      {:ok, user} ->
        Enum.each(Asset.get_placeholder_assets(), fn placeholder_asset ->
          Asset.ensure_user_asset_lease(placeholder_asset, user, %{})
        end)

        conn
        |> renew_session()
        |> put_session(:user_token, token)
        |> put_session(:mv_token, nil)
        |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
        |> maybe_write_remember_me_cookie(token, params)
        |> redirect(to: user_return_to || signed_in_path(conn))

      _ ->
        conn
        |> put_flash(:error, "Unable to record the login in Database")
        |> put_status(:unprocessable_entity)
        |> halt()
    end
  end

  def mv_create_user(conn, user, mv_token, params \\ %{}) do
    token = User.generate_user_token(user, mv_token, "session")
    user_return_to = get_session(conn, :user_return_to)

    case User.record_login(user) do
      {:ok, user} ->
        Enum.each(Asset.get_placeholder_assets(), fn placeholder_asset ->
          Asset.ensure_user_asset_lease(placeholder_asset, user, %{})
        end)

        conn
        |> renew_session()
        |> put_session(:user_token, token)
        |> put_session(:mv_token, mv_token)
        |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
        |> maybe_write_remember_me_cookie(token, params)
        |> redirect(to: user_return_to || signed_in_path(conn))

      _ ->
        conn
        |> put_flash(:error, "Unable to record the login in Database")
        |> put_status(:unprocessable_entity)
        |> halt()
    end
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, Application.fetch_env!(:darth, :remember_me_cookie), token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def logout_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && User.delete_token(user_token, "session")

    if live_socket_id = get_session(conn, :live_socket_id) do
      DarthWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(Application.fetch_env!(:darth, :remember_me_cookie))
    |> redirect(to: "/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, mv_token, conn} = ensure_user_token(conn)
    user = user_token && User.get_user_by_token(user_token, "session")

    conn
    |> assign(:current_user, user)
    |> assign(:user_token, user_token)
    |> assign(:mv_token, mv_token)
  end

  def ensure_user_login(conn, _opts) do
    with {:ok, user_token, context} <- get_token(conn),
         %UserStruct{} = user <- User.get_user_by_token(user_token, context) do
      conn
      |> assign(:current_api_user, user)
      |> assign(:api_user_token, user_token)
    else
      _ ->
        conn
        |> Plug.Conn.send_resp(422, Jason.encode!(:unprocessable_entity))
        |> halt
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        get_api_token(token)

      _ ->
        get_session_token(conn)
    end
  end

  defp get_api_token(user_token) do
    case Base.decode64(user_token) do
      {:ok, user_token} -> {:ok, user_token, "api"}
      _ -> :error
    end
  end

  defp get_session_token(conn) do
    case get_session(conn, :user_token) do
      nil ->
        :error

      user_token ->
        {:ok, user_token, "session"}
    end
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      mv_token = get_session(conn, :mv_token)
      {user_token, mv_token, conn}
    else
      conn = fetch_cookies(conn, signed: [Application.fetch_env!(:darth, :remember_me_cookie)])

      if user_token = conn.cookies[Application.fetch_env!(:darth, :remember_me_cookie)] do
        {user_token, put_session(conn, :user_token, user_token), put_session(conn, :mv_token, nil)}
      else
        {nil, nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  def redirect_if_user_is_mv_authenticated(conn, _opts) do
    with %UserStruct{} = current_user <- conn.assigns[:current_user],
         false <- is_nil(current_user.mv_node) do
      conn
      |> redirect(to: redirect_path(conn))
      |> halt()
    else
      _ -> conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> redirect(to: Routes.user_session_path(conn, :new))
      |> halt()
    end
  end

  def required_mv_authenticated_user(conn, _opts) do
    with %UserStruct{} = current_user <- conn.assigns[:current_user],
         false <- is_nil(current_user.mv_node) do
      conn
    else
      _ ->
        conn
        |> redirect(to: Routes.user_session_path(conn, :mv_create))
        |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"

  defp redirect_path(conn) do
    case URI.decode_query(conn.query_string) do
      %{"mv_project_id" => mv_project_id} ->
        Routes.mv_project_show_path(conn, :show, mv_project_id)

      %{} ->
        "/"
    end
  end
end

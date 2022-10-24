defmodule DarthWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

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
      {:ok, _user} ->
        conn
        |> renew_session()
        |> put_session(:user_token, token)
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

  def mv_login_user(conn, user, token, params \\ %{}) do
    token = User.generate_user_token(user, token, "session")
    user_return_to = get_session(conn, :user_return_to)

    case User.record_login(user) do
      {:ok, _user} ->
        conn
        |> renew_session()
        |> put_session(:user_token, token)
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
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && User.get_user_by_token(user_token, "session")

    conn
    |> assign(:current_user, user)
    |> assign(:user_token, user_token)
  end

  def ensure_user_login(conn, _opts) do
    with {:ok, user_token} <- get_token(conn),
         %UserStruct{} = user <- User.get_user_by_token(user_token, "api") do
      conn
      |> assign(:current_api_user, user)
      |> assign(:api_user_token, user_token)
    else
      _ ->
        conn
        |> Plug.Conn.send_resp(422, Poison.encode!(:unprocessable_entity))
        |> halt
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> Base.decode64(token)
      _ -> :error
    end
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [Application.fetch_env!(:darth, :remember_me_cookie)])

      if user_token = conn.cookies[Application.fetch_env!(:darth, :remember_me_cookie)] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
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
      |> redirect(to: signed_in_path(conn))
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
        |> redirect(to: Routes.user_session_path(conn, :mv_login))
        |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"
end

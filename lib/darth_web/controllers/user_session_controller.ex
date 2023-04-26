defmodule DarthWeb.UserSessionController do
  use DarthWeb, :controller

  require Logger

  alias Darth.MvApiClient
  alias Darth.Model.User, as: UserModel
  alias Darth.Controller.User
  alias DarthWeb.UserAuth

  def new(conn, _params) do
    conn
    |> render("new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.change_user_registration(%UserModel{})
    %{"email" => email, "password" => password} = user_params

    with %UserModel{} = user <- User.get_user_by_email_and_password(email, password),
         true <- is_nil(user.mv_node) do
      UserAuth.login_user(conn, user, user_params)
    else
      false ->
        conn
        |> put_flash(:info, "Provided credentials are for MediaVerse account, login here")
        |> render("mv_new.html",
          default_mv_node:
            get_mv_api_endpoint(Map.get(user_params, "mv_node", Application.fetch_env!(:darth, :default_mv_node))),
          changeset: changeset,
          username_error: false
        )

      _ ->
        conn
        |> render("new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.logout_user()
  end

  def mv_new(conn, params) do
    mv_node = get_mv_api_endpoint(Map.get(params, "mv_node", Application.fetch_env!(:darth, :default_mv_node)))

    changeset = User.change_user_registration(%UserModel{})

    conn
    |> render("mv_new.html",
      default_mv_node: mv_node,
      changeset: changeset,
      username_error: false
    )
  end

  # Reusing the mv_login page by making user_name error as true.
  #  As there will be no changeset errors just the username field is displayed
  def mv_register(conn, params) do
    mv_node = get_mv_api_endpoint(Map.get(params, "mv_node", Application.fetch_env!(:darth, :default_mv_node)))

    changeset = User.change_user_registration(%UserModel{})

    conn
    |> render("mv_new.html",
      default_mv_node: mv_node,
      changeset: changeset,
      username_error: true
    )
  end

  def mv_create(conn, params) do
    user_params = Map.get(params, "user")
    email = Map.get(user_params, "email")
    mv_node = Map.get(user_params, "mediaverse_node")
    password = Map.get(user_params, "password")

    with {:ok, %{"token" => mv_token}} <- MvApiClient.authenticate(mv_node, email, password),
         {:ok, mv_user} <- MvApiClient.fetch_user(mv_node, mv_token),
         {:ok, user} <- create_mv_user_struct(mv_user, user_params),
         false <- is_nil(user.mv_node) do
      conn
      |> UserAuth.mv_create_user(user, mv_token)
    else
      # Databse error
      {:error, %Ecto.Changeset{} = changeset} ->
        database_error(conn, changeset, mv_node)

      true ->
        conn
        |> put_flash(:info, "Provided credentials are for Fader account, login here")
        |> render("new.html", error_message: nil)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error(conn, mv_node, "Server response error")

      # Custom error message from MediaVerse
      {:ok, %{"message" => message}} ->
        Logger.info(inspect(message))
        error(conn, mv_node, message)

      {:error, reason, _} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error(conn, mv_node, "Custom error message from MediaVerse: #{inspect(reason)}")

      {:error, %Jason.DecodeError{} = reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error(conn, mv_node, "User not found for provided mv_node")

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error(conn, mv_node, "Custom error message from MediaVerse: #{inspect(reason)}")
    end
  end

  def create_mv_user_struct(mv_user, user_params) do
    email = Map.get(user_params, "email")
    mv_node = Map.get(user_params, "mediaverse_node")
    password = Map.get(user_params, "password")
    username = Map.get(user_params, "username")
    firstname = Map.get(mv_user, "firstname")
    surname = Map.get(mv_user, "lastname")
    display_name = firstname <> " " <> surname

    user_params = %{
      "display_name" => display_name,
      "email" => email,
      "firstname" => firstname,
      "password" => password,
      "password_confirmation" => password,
      "surname" => surname,
      "username" => username,
      "is_email_verified" => true,
      "mv_node" => mv_node
    }

    with %UserModel{} = user_struct <-
           User.get_user_by_email_password_and_mv_node(email, password, mv_node) do
      {:ok, user_struct}
    else
      _ -> User.create(user_params)
    end
  end

  defp database_error(conn, changeset, mv_node) do
    username_error = username_error?(changeset)

    conn
    |> render("mv_new.html",
      default_mv_node: mv_node,
      changeset: changeset,
      username_error: username_error
    )
  end

  defp username_error?(%Ecto.Changeset{} = changeset) do
    case changeset.errors[:username] do
      {"has already been taken", _} -> true
      {"can't be blank", _} -> true
      _ -> false
    end
  end

  defp error(conn, mv_node, reason) do
    conn
    |> put_flash(:error, "MediaVerse login failed due to: #{reason}")
    |> redirect(to: Routes.user_session_path(conn, :mv_new, mv_node: mv_node))
  end

  defp get_mv_api_endpoint(mv_node) do
    Path.join([mv_node, Application.fetch_env!(:darth, :mv_api_endpoint)])
  end
end

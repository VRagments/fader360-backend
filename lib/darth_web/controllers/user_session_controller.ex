defmodule DarthWeb.UserSessionController do
  use DarthWeb, :controller

  require Logger

  alias Darth.MvApiClient
  alias Darth.Model.User, as: UserModel
  alias Darth.Model.UserToken
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
        |> render("mv_login.html",
          default_mv_node: Application.fetch_env!(:darth, :default_mv_node),
          changeset: changeset,
          username_taken: false
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

  def mv_login(conn, _params) do
    changeset = User.change_user_registration(%UserModel{})

    with %UserModel{} = current_user <- conn.assigns.current_user,
         %UserToken{} <- User.get_user_token_struct(current_user) do
      conn
      |> redirect(to: "/")
    else
      _ ->
        conn
        |> render("mv_login.html",
          default_mv_node: Application.fetch_env!(:darth, :default_mv_node),
          changeset: changeset,
          username_taken: false
        )
    end
  end

  def mv_login_post(conn, params) do
    user_params = Map.get(params, "user")
    email = Map.get(user_params, "email")
    mv_node = Map.get(user_params, "mediaverse_node")
    password = Map.get(user_params, "password")

    with {:ok, %{"token" => mv_token}} <- MvApiClient.authenticate(mv_node, email, password),
         {:ok, mv_user} <- MvApiClient.fetch_user(mv_node, mv_token),
         {:ok, user} <- get_user_struct(mv_user, user_params),
         false <- is_nil(user.mv_node) do
      conn
      |> UserAuth.mv_login_user(user, mv_token)
    else
      # Databse error
      {:error, %Ecto.Changeset{} = changeset} ->
        database_error(conn, changeset)

      true ->
        conn
        |> put_flash(:info, "Provided credentials are for Fader account, login here")
        |> render("new.html", error_message: nil)

      {:error, %Jason.EncodeError{message: message}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(message)}")
        error(conn, "Invalid credentials")

      {:error, %Jason.DecodeError{data: data}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(data)}")
        error(conn, "Invalid URL")

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error(conn, "Server response error")

      # Custom error message from MediaVerse
      {:ok, %{"message" => message}} ->
        Logger.info(inspect(message))
        error(conn, message)
    end
  end

  def get_user_struct(mv_user, user_params) do
    email = Map.get(user_params, "email")
    mv_node = Map.get(user_params, "mediaverse_node")
    password = Map.get(user_params, "password")
    username = get_username(mv_user, user_params)
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

    with %UserModel{} = user_struct <- User.get_user_by_email_and_password(email, password) do
      {:ok, user_struct}
    else
      _ -> User.create(user_params)
    end
  end

  defp get_username(mv_user, user_params) do
    case Map.get(user_params, "username") do
      nil ->
        Map.get(mv_user, "username")

      user_name ->
        user_name
    end
  end

  defp database_error(conn, changeset) do
    username_taken = username_already_taken?(changeset)

    conn
    |> render("mv_login.html",
      default_mv_node: Application.fetch_env!(:darth, :default_mv_node),
      changeset: changeset,
      username_taken: username_taken
    )
  end

  defp username_already_taken?(%Ecto.Changeset{} = changeset) do
    case changeset.errors[:username] do
      {"has already been taken", _} -> true
      _ -> false
    end
  end

  defp error(conn, reason) do
    conn
    |> put_flash(:error, "MediaVerse login failed due to: #{reason}")
    |> redirect(to: Routes.user_session_path(conn, :mv_login))
  end
end

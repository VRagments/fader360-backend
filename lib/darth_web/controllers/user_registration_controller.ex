defmodule DarthWeb.UserRegistrationController do
  use DarthWeb, :controller
  alias Darth.Model.User, as: UserModel
  alias Darth.Controller.User
  alias DarthWeb.UserAuth

  def new(conn, _params) do
    changeset = User.change_user_registration(%UserModel{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case User.create(user_params) do
      {:ok, user} ->
        {:ok, _} =
          User.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :edit, &1)
          )

        conn
        |> put_flash(
          :info,
          "User created successfully. Please verify your email through the verification link we've sent to
                         your email address."
        )
        |> UserAuth.login_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end

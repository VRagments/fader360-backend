defmodule DarthWeb.LivePage.Page do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User

  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session") do
      {:ok,
       socket
       |> assign(current_user: user)}
    else
      _ ->
        Logger.error("Error message from MediaVerse: User not found")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LivePage.Page))

        {:ok, socket}
    end
  end
end
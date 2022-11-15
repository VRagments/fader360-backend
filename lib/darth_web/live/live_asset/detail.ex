defmodule DarthWeb.LiveAsset.Detail do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias DarthWeb.AssetView

  @impl Phoenix.LiveView
  def mount(%{"asset_id" => asset_id}, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         {:ok, asset} <- Asset.read(asset_id),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets") do
      {:ok,
       socket
       |> assign(current_user: user, asset: asset)}
    else
      {:error, :not_found} ->
        Logger.error("Error message: Asset not found")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:ok, socket}

      _ ->
        Logger.error("Error message from MediaVerse: User not found")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, asset}, socket) do
    case socket.assigns.asset.id == asset.id do
      true ->
        {:noreply, socket |> assign(asset: asset)}

      false ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, asset}, socket) do
    case socket.assigns.asset.id == asset.id do
      true ->
        socket =
          socket
          |> put_flash(:info, "Asset deleted successfully")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      false ->
        {:noreply, socket}
    end
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end
end

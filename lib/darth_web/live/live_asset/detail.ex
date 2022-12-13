defmodule DarthWeb.LiveAsset.Detail do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease

  @impl Phoenix.LiveView
  def mount(%{"asset_lease_id" => asset_lease_id}, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         {:ok, asset_lease} <- AssetLease.read(asset_lease_id, true),
         true <- AssetLease.has_user?(asset_lease, user.id),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets") do
      {:ok,
       socket
       |> assign(current_user: user, asset: asset_lease.asset)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:ok, socket}

      false ->
        Logger.error("Error message: Current user don't have access to this Asset")

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this Asset")
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
    socket =
      if socket.assigns.asset.id == asset.id do
        assign(socket, asset: asset)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, asset}, socket) do
    socket =
      if socket.assigns.asset.id == asset.id do
        socket
        |> put_flash(:info, "Asset deleted successfully")
        |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def get_width(attributes) do
    Map.get(attributes, "width")
  end

  def get_height(attributes) do
    Map.get(attributes, "height")
  end

  def get_file_size(attributes) do
    size = Map.get(attributes, "file_size")

    (size * 0.000001)
    |> Float.round(2)
    |> inspect
  end

  def get_duration(attributes) do
    duration = Map.get(attributes, "duration")

    case duration > 0 do
      true ->
        duration
        |> Float.round(2)
        |> inspect

      false ->
        duration
    end
  end
end

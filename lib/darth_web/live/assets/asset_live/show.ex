defmodule DarthWeb.Assets.AssetLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease
  alias DarthWeb.Components.Header
  alias DarthWeb.Components.Show

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
      {:ok, socket |> assign(current_user: user)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:ok, socket}

      nil ->
        Logger.error("Error message from MediaVerse: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"asset_lease_id" => asset_lease_id}, _url, socket) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         true <- AssetLease.has_user?(asset_lease, socket.assigns.current_user.id) do
      {:noreply, socket |> assign(asset_lease: asset_lease)}
    else
      false ->
        Logger.error("Error message: Current user don't have access to this Asset")

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this Asset")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Error while fetching asset and projects")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:noreply, socket}

      nil ->
        Logger.error("Error message: Asset not found in database")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, asset}, socket) do
    socket =
      if socket.assigns.asset_lease.asset.id == asset.id do
        updated_asset_lease =
          socket.assigns.asset_lease
          |> Map.put(:asset, asset)

        assign(socket, asset_lease: updated_asset_lease)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, asset}, socket) do
    socket =
      if socket.assigns.asset_lease.asset.id == asset.id do
        socket
        |> put_flash(:info, "Asset deleted successfully")
        |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_width(attributes) do
    Map.get(attributes, "width")
  end

  defp get_height(attributes) do
    Map.get(attributes, "height")
  end

  defp get_file_size(attributes) do
    size = Map.get(attributes, "file_size")

    (size * 0.000001)
    |> Float.round(2)
    |> inspect
  end

  defp get_duration(attributes) do
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

  defp render_audio_asset_detail(assigns) do
    ~H"""
    <Show.render type="audio_asset"
      source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      data_source={@asset_lease.asset.static_url}
      file_size={get_file_size(@asset_lease.asset.attributes)}
      duration={get_duration(@asset_lease.asset.attributes)} status={@asset_lease.asset.status}
      media_type={@asset_lease.asset.media_type} />
    """
  end

  defp render_video_asset_detail(assigns) do
    ~H"""
    <Show.render type="video_asset" data_source={@asset_lease.asset.static_url}
      width={get_width(@asset_lease.asset.attributes)}
      height={get_height(@asset_lease.asset.attributes)}
      file_size={get_file_size(@asset_lease.asset.attributes)}
      duration={get_duration(@asset_lease.asset.attributes)} status={@asset_lease.asset.status}
      media_type={@asset_lease.asset.media_type} />
    """
  end

  defp render_image_asset_detail(assigns) do
    ~H"""
    <Show.render type="image_asset" source={@asset_lease.asset.static_url}
      width={get_width(@asset_lease.asset.attributes)}
      height={get_height(@asset_lease.asset.attributes)}
      file_size={get_file_size(@asset_lease.asset.attributes)} status={@asset_lease.asset.status}
      media_type={@asset_lease.asset.media_type} />
    """
  end
end
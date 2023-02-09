defmodule DarthWeb.MvAssetLive.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease
  alias Darth.{MvApiClient, AssetProcessor.Downloader, AssetProcessor.PreviewDownloader}
  alias DarthWeb.Components.IndexCard

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_previews") do
      {:ok, socket |> assign(current_user: user, mv_token: mv_token)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.PageLive.Page))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.PageLive.Page))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    mv_token = socket.assigns.mv_token
    mv_node = socket.assigns.current_user.mv_node
    asset_preview_static_url = Application.get_env(:darth, :asset_preview_static_url)

    case MvApiClient.fetch_assets(mv_node, mv_token) do
      {:ok, assets} ->
        add_to_preview_downloader(assets, mv_node, mv_token)
        {:noreply, socket |> assign(mv_assets: assets, asset_preview_static_url: asset_preview_static_url)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

        {:noreply, socket}

      err ->
        Logger.error("Custom error message from MediaVerse: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, inspect(err))
          |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, _asset}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, _asset}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_preview_downloaded, _}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("add_mv_asset", %{"ref" => mv_asset_key}, socket) do
    add_to_fader(socket, mv_asset_key)
  end

  @impl Phoenix.LiveView
  def handle_event("add_all_mv_assets", _, socket) do
    mv_assets = socket.assigns.mv_assets

    for mv_asset <- mv_assets do
      mv_asset_key = Map.get(mv_asset, "key")

      case Asset.read_by(%{mv_asset_key: mv_asset_key}) do
        {:ok, _} -> :ok
        {:error, _} -> add_to_fader(socket, mv_asset_key)
      end
    end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_mv_asset", %{"ref" => mv_asset_key}, socket) do
    with {:ok, asset} <- Asset.read_by(%{mv_asset_key: mv_asset_key}),
         {:ok, asset_lease} <- AssetLease.read_by(%{asset_id: asset.id}),
         {:ok, asset_lease} <- AssetLease.remove_user(asset_lease, socket.assigns.current_user),
         :ok <- AssetLease.maybe_delete(asset_lease),
         :ok <- Asset.delete(asset) do
      socket =
        socket
        |> put_flash(:info, "Asset removed successfully")
        |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

      {:noreply, socket}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {reason_atom, _} = List.first(changeset.errors)

        delete_message = handle_asset_lease_deletion(reason_atom, socket.assigns.current_user, mv_asset_key)
        Logger.error("Error message while deleting asset_lease: #{inspect(delete_message)}")

        socket =
          socket
          |> put_flash(:error, delete_message)
          |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message while deleting asset_lease: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Asset cannot be deleted: #{inspect(reason)}")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

        {:noreply, socket}
    end
  end

  defp handle_asset_lease_deletion(:projects_asset_leases, user, mv_asset_key) do
    with {:ok, asset} <- Asset.read_by(%{mv_asset_key: mv_asset_key}),
         {:ok, asset_lease} <- AssetLease.read_by(%{asset_id: asset.id}),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Asset cannot be deleted as it is being used in projects"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp handle_asset_lease_deletion(:user_asset_leases, user, mv_asset_key) do
    with {:ok, asset} <- Asset.read_by(%{mv_asset_key: mv_asset_key}),
         {:ok, asset_lease} <- AssetLease.read_by(%{asset_id: asset.id}),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Asset cannot be deleted as it is being used by other user"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp handle_asset_lease_deletion(:projects, user, mv_asset_key) do
    with {:ok, asset} <- Asset.read_by(%{mv_asset_key: mv_asset_key}),
         {:ok, asset_lease} <- AssetLease.read_by(%{asset_id: asset.id}),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Asset cannot be deleted as it is used as a primary asset in project"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp handle_asset_lease_deletion(error, user, mv_asset_key) do
    with {:ok, asset} <- Asset.read_by(%{mv_asset_key: mv_asset_key}),
         {:ok, asset_lease} <- AssetLease.read_by(%{asset_id: asset.id}),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Error while deleting the asset: #{inspect(error)}"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp add_to_preview_downloader(assets, mv_node, mv_token) do
    for asset <- assets do
      filename = Map.get(asset, "originalFilename")
      asset_previewlink_key = Map.get(asset, "previewLinkKey")

      file_path =
        Path.join([Application.get_env(:darth, :mv_asset_preview_download_path), asset_previewlink_key, filename])

      if File.exists?(file_path) do
        :ok
      else
        download_params = %{
          mv_asset_previewlink_key: asset_previewlink_key,
          mv_node: mv_node,
          mv_token: mv_token,
          mv_asset_filename: filename
        }

        PreviewDownloader.add_preview_download_params(download_params)
      end
    end
  end

  defp add_to_fader(socket, mv_asset_key) do
    mv_node = socket.assigns.current_user.mv_node
    mv_token = socket.assigns.mv_token

    with {:ok, asset} <- MvApiClient.show_asset(mv_node, mv_token, mv_asset_key),
         download_params = %{
           media_type: Map.get(asset, "contentType"),
           mv_asset_key: Map.get(asset, "key"),
           mv_asset_deeplink_key: Map.get(asset, "deepLinkKey"),
           mv_node: mv_node,
           mv_token: mv_token,
           mv_asset_filename: Map.get(asset, "originalFilename"),
           current_user: socket.assigns.current_user
         },
         :ok <- Downloader.add_download_params(download_params) do
      socket =
        socket
        |> put_flash(:info, "Downloading MediaVerse Asset")
        |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

      {:noreply, socket}
    else
      {:ok, %{"message" => message}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

        socket =
          socket
          |> put_flash(:error, message)
          |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

        {:noreply, socket}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Server response error")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> push_patch(to: Routes.live_path(socket, DarthWeb.MvAssetLive.Index))

        {:noreply, socket}
    end
  end

  defp render_audio_card(assigns) do
    ~H"""
    <IndexCard.render title={Map.get(@mv_asset, "originalFilename" )}
      visibility={Map.get(@mv_asset, "contentType" )} subtitle={Map.get(@mv_asset, "createdBy"
      )} button_one_label="View" button_two_label="Add to Fader"
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      button_two_action="add_mv_asset" button_two_phx_value_ref={Map.get(@mv_asset, "key" )}
      button_one_route={String.replace_suffix(@current_user.mv_node,"dam", "app/audio/" )<>
      Map.get(@mv_asset, "key")} button_one_action="view" audio_source={Path.join([@asset_preview_static_url,
      Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])} />
    """
  end

  defp render_video_card(assigns) do
    ~H"""
    <IndexCard.render title={Map.get(@mv_asset, "originalFilename" )}
      visibility={Map.get(@mv_asset, "contentType" )} subtitle={Map.get(@mv_asset, "createdBy" )}
      button_one_label="View" button_two_label="Add to Fader"
      image_source={Path.join([@asset_preview_static_url,
      Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
      button_two_action="add_mv_asset" button_two_phx_value_ref={Map.get(@mv_asset, "key"
      )} button_one_route={String.replace_suffix(@current_user.mv_node,"dam", "app/video/"
      )<>Map.get(@mv_asset, "key")} button_one_action="view" />
    """
  end

  defp render_image_card(assigns) do
    ~H"""
    <IndexCard.render title={Map.get(@mv_asset, "originalFilename" )}
      visibility={Map.get(@mv_asset, "contentType" )} subtitle={Map.get(@mv_asset, "createdBy"
      )} button_one_label="View" button_two_label="Add to Fader"
      image_source={Path.join([@asset_preview_static_url, Map.get(@mv_asset, "previewLinkKey"
      ), Map.get(@mv_asset, "originalFilename" )])} button_two_action="add_mv_asset"
      button_two_phx_value_ref={Map.get(@mv_asset, "key" )}
      button_one_route={String.replace_suffix(@current_user.mv_node,"dam", "app/image/" )<>
      Map.get(@mv_asset, "key")} button_one_action="view" />
    """
  end

  defp render_default_card(assigns) do
    ~H"""
    <IndexCard.render title={Map.get(@mv_asset, "originalFilename" )}
      visibility={Map.get(@mv_asset, "contentType" )} button_two_label="Add to Fader"
      subtitle={Map.get(@mv_asset, "createdBy" )} button_one_label="View"
      image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
      button_one_action="view" button_two_action="add_mv_asset"
      button_two_phx_value_ref={Map.get(@mv_asset, "key" )} />
    """
  end
end

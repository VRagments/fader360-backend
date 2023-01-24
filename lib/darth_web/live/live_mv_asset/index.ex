defmodule DarthWeb.LiveMvAsset.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease
  alias Darth.Model.Asset, as: Assetstruct
  alias Darth.{MvApiClient, AssetProcessor.Downloader}

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases") do
      {:ok, socket |> assign(current_user: user, mv_token: mv_token)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LivePage.Page))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LivePage.Page))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    mv_token = socket.assigns.mv_token
    mv_node = socket.assigns.current_user.mv_node

    case MvApiClient.fetch_assets(mv_node, mv_token) do
      {:ok, assets} ->
        {:noreply, socket |> assign(mv_assets: assets)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:noreply, socket}

      err ->
        Logger.error("Custom error message from MediaVerse: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, inspect(err))
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, _asset}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, _asset}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("add_mv_asset", %{"ref" => mv_asset_key}, socket) do
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
        |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

      {:noreply, socket}
    else
      {:ok, %{"message" => message}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

        socket =
          socket
          |> put_flash(:error, message)
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:noreply, socket}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Server response error")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:noreply, socket}
    end
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
        |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

      {:noreply, socket}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {reason_atom, _} = List.first(changeset.errors)

        delete_message = handle_asset_lease_deletion(reason_atom, socket.assigns.current_user, mv_asset_key)
        Logger.error("Error message while deleting asset_lease: #{inspect(delete_message)}")

        socket =
          socket
          |> put_flash(:error, delete_message)
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message while deleting asset_lease: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Asset cannot be deleted: #{inspect(reason)}")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:noreply, socket}
    end
  end

  defp asset_already_added?(mv_asset_key) do
    case Asset.get_asset_with_mv_asset_key(mv_asset_key) do
      %Assetstruct{} = asset_struct -> asset_struct.status == "ready"
      _ -> false
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
end

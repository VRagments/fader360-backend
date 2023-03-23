defmodule DarthWeb.Assets.AssetLive.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.AssetLease
  alias DarthWeb.UploadProcessor

  alias DarthWeb.Components.{
    Header,
    FormUpload,
    EmptyState,
    UploadProgress,
    IndexCard,
    IndexCardClickButtonGroup,
    Pagination
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         upload_file_size = Application.fetch_env!(:darth, :upload_file_size),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases") do
      {:ok,
       socket
       |> assign(current_user: user)
       |> assign(:uploaded_files, [])
       |> allow_upload(:media, accept: ~w(audio/* video/* image/*), max_entries: 1, max_file_size: upload_file_size)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    case AssetLease.query_by_user(socket.assigns.current_user.id, params, false) do
      %{query_page: current_page, total_pages: total_pages, entries: asset_leases} ->
        map_with_all_links = map_with_all_links(socket, total_pages)
        asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end)
        asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

        {:noreply,
         socket
         |> assign(
           current_page: current_page,
           total_pages: total_pages,
           asset_leases_map: asset_leases_map,
           asset_leases_list: asset_leases_list,
           map_with_all_links: map_with_all_links
         )}

      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching asset via asset leases: #{query_error}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> redirect(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}

      err ->
        Logger.error("Error message: Database error while fetching asset via asset leases: #{err}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> redirect(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, asset}, socket) do
    asset_leases_map = socket.assigns.asset_leases_map
    asset_lease_tuple = asset_leases_map |> Enum.find(fn {_, value} -> asset.id == value.asset.id end)

    socket =
      if is_nil(asset_lease_tuple) do
        socket
      else
        {_, asset_lease} = asset_lease_tuple
        updated_asset_lease = Map.put(asset_lease, :asset, asset)
        updated_asset_leases_map = Map.put(asset_leases_map, updated_asset_lease.id, updated_asset_lease)
        asset_leases_list = Asset.get_sorted_asset_lease_list(updated_asset_leases_map)
        socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: updated_asset_leases_map)
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_created, _asset_lease}, socket) do
    get_updated_asset_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_updated, asset_lease}, socket) do
    asset_leases_map = socket.assigns.asset_leases_map
    updated_asset_leases_map = Map.put(asset_leases_map, asset_lease.id, asset_lease)
    asset_leases_list = Asset.get_sorted_asset_lease_list(updated_asset_leases_map)

    {:noreply, socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: updated_asset_leases_map)}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_deleted, _asset_lease}, socket) do
    get_updated_asset_list(socket)
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    user = socket.assigns.current_user

    socket =
      with :ok <- UploadProcessor.create_uploads_base_path(),
           {:ok, uploaded_file_path} <- UploadProcessor.get_uploaded_entries(socket),
           {:ok, asset_details} <- UploadProcessor.get_asset_details(socket, uploaded_file_path),
           :ok <- UploadProcessor.check_for_uploaded_asset_media_type(asset_details),
           {:ok, asset_struct} <- Asset.create(asset_details),
           {:ok, _lease} <- AssetLease.create_for_user(asset_struct, user),
           :ok <- File.rm(uploaded_file_path) do
        socket
        |> put_flash(:info, "Uploaded Successfully")
        |> push_patch(to: Routes.asset_index_path(socket, :index, page: socket.assigns.current_page))
      else
        {:error, reason} ->
          Logger.error("Error while uploading the asset: #{inspect(reason)}")

          socket
          |> put_flash(:error, inspect(reason))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("re_transcode", %{"ref" => asset_id}, socket) do
    socket =
      case Phoenix.PubSub.broadcast(Darth.PubSub, "assets", {:asset_transcode, asset_id}) do
        :ok ->
          socket
          |> put_flash(:info, "Re-transcoding asset")
          |> push_patch(to: Routes.asset_index_path(socket, :index, page: socket.assigns.current_page))

        error ->
          socket
          |> put_flash(:error, "Unable to start asset Re-transcoding: #{error}")
          |> push_patch(to: Routes.asset_index_path(socket, :index, page: socket.assigns.current_page))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"ref" => asset_lease_id}, socket) do
    socket =
      with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
           {:ok, asset_lease} <- AssetLease.remove_user(asset_lease, socket.assigns.current_user),
           :ok <- AssetLease.maybe_delete(asset_lease),
           :ok <- Asset.delete(asset_lease.asset) do
        socket
        |> put_flash(:info, "Asset deleted successfully")
        |> push_navigate(to: Routes.asset_index_path(socket, :index, page: socket.assigns.current_page))
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          {reason_atom, _} = List.first(changeset.errors)

          delete_message = handle_asset_lease_deletion(reason_atom, socket.assigns.current_user, asset_lease_id)
          Logger.error("Error message while deleting asset_lease: #{inspect(delete_message)}")

          socket
          |> put_flash(:error, delete_message)
          |> push_navigate(to: Routes.asset_index_path(socket, :index, page: socket.assigns.current_page))

        {:error, reason} ->
          Logger.error("Error message while deleting asset_lease: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Asset cannot be deleted: #{inspect(reason)}")
          |> push_navigate(to: Routes.asset_index_path(socket, :index, page: socket.assigns.current_page))
      end

    {:noreply, socket}
  end

  defp get_updated_asset_list(socket) do
    socket =
      case AssetLease.query_by_user(socket.assigns.current_user.id, %{}, false) do
        %{entries: asset_leases} ->
          asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end)
          asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

          socket
          |> assign(asset_leases_list: asset_leases_list, asset_leases_map: asset_leases_map)

        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching asset via asset leases: #{query_error}")

          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> redirect(to: Routes.asset_index_path(socket, :index))

        _ ->
          Logger.error("Error message: User not found while fetching assests")

          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.asset_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  defp handle_asset_lease_deletion(:projects_asset_leases, user, asset_lease_id) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Asset cannot be deleted as it is being used in projects"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp handle_asset_lease_deletion(:user_asset_leases, user, asset_lease_id) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Asset cannot be deleted as it is being used by other user"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp handle_asset_lease_deletion(:projects, user, asset_lease_id) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Asset cannot be deleted as it is used as a primary asset in project"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp handle_asset_lease_deletion(error, user, asset_lease_id) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      "Error while deleting the asset: #{inspect(error)}"
    else
      {:error, reason} ->
        "Error while deleting the asset: #{inspect(reason)}"

      nil ->
        "Asset not found"
    end
  end

  defp map_with_all_links(socket, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.asset_index_path(socket, :index, page: page)}
    end)
  end

  defp render_audio_card(assigns) do
    ~H"""
    <IndexCard.render
      show_path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      title={@asset_lease.asset.name}
      subtitle={@asset_lease.asset.media_type}
      info={@asset_lease.asset.status}
    >
      <IndexCardClickButtonGroup.render
        button_one_action="re_transcode"
        button_one_phx_value_ref={@asset_lease.asset.id}
        button_one_label="Re-Transcode"
        button_two_action="delete"
        button_two_phx_value_ref={@asset_lease.id}
        button_two_label="Delete"
        confirm_message="Do you really want to delete this asset? This action cannot be reverted."
      />
    </IndexCard.render>
    """
  end

  defp render_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        image_source={@asset_lease.asset.thumbnail_image}
        title={@asset_lease.asset.name}
        subtitle={@asset_lease.asset.media_type}
        info={@asset_lease.asset.status}
      >
        <IndexCardClickButtonGroup.render
          button_one_action="re_transcode"
          button_one_phx_value_ref={@asset_lease.asset.id}
          button_one_label="Re-Transcode"
          button_two_action="delete"
          button_two_phx_value_ref={@asset_lease.id}
          button_two_label="Delete"
          confirm_message="Do you really want to delete this asset? This action cannot be reverted."
        />
      </IndexCard.render>
    """
  end

  defp render_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
        title={@asset_lease.asset.name}
        subtitle={@asset_lease.asset.media_type}
        info={@asset_lease.asset.status}
      >
        <IndexCardClickButtonGroup.render
          button_one_action="re_transcode"
          button_one_phx_value_ref={@asset_lease.asset.id}
          button_one_label="Re-Transcode"
          button_two_action="delete"
          button_two_phx_value_ref={@asset_lease.id}
          button_two_label="Delete"
          confirm_message="Do you really want to delete this asset? This action cannot be reverted."
        />
      </IndexCard.render>
    """
  end

  defp render_asset_card(assigns) do
    if Asset.is_asset_status_ready?(assigns.asset_lease.asset.status) do
      render_asset_media_card(assigns)
    else
      render_default_card(assigns)
    end
  end

  defp render_asset_media_card(assigns) do
    media_type = Asset.normalized_media_type(assigns.asset_lease.asset.media_type)

    case media_type do
      :audio -> render_audio_card(assigns)
      :video -> render_image_card(assigns)
      :image -> render_image_card(assigns)
    end
  end
end

defmodule DarthWeb.Assets.AssetLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  alias(Darth.Model.User, as: UserStruct)
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease
  alias Darth.Controller.AssetSubtitle
  alias Darth.AssetProcessor.AssetSubtitleDownloader
  alias Darth.Model.AssetSubtitle, as: AssetSubtitleStruct
  alias DarthWeb.UploadProcessor

  alias DarthWeb.Components.{
    ShowAudio,
    ShowVideo,
    ShowImage,
    Stat,
    Icons,
    Header,
    EmptyState,
    HeaderButtons,
    SubtitlesTable
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         upload_subtitle_file_size = Application.fetch_env!(:darth, :upload_subtitle_file_size),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_subtitles") do
      {:ok,
       socket
       |> assign(current_user: user, mv_token: mv_token)
       |> assign(:uploaded_files, [])
       |> allow_upload(:subtitle,
         accept: ~w(.srt),
         max_entries: 1,
         max_file_size: upload_subtitle_file_size
       )}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}

      nil ->
        Logger.error("Error message from MediaVerse: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"asset_lease_id" => asset_lease_id}, _url, socket) do
    select_options = Ecto.Enum.mappings(AssetSubtitleStruct, :language)

    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         true <- AssetLease.has_user?(asset_lease, socket.assigns.current_user.id),
         asset_subtitles <- AssetSubtitle.query_by_asset(asset_lease.asset.id) do
      {:noreply,
       socket
       |> assign(
         asset_lease: asset_lease,
         asset_subtitles: asset_subtitles,
         asset_subtitle_language_select_options: select_options
       )}
    else
      false ->
        Logger.error("Error message: Current user don't have access to this Asset")

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this Asset")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Error while fetching asset and projects")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}

      nil ->
        Logger.error("Error message: Asset not found in database")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"ref" => asset_subtitle_id}, socket) do
    socket =
      with {:ok, asset_subtitle} <- AssetSubtitle.read(asset_subtitle_id),
           :ok <- AssetSubtitle.delete(asset_subtitle) do
        socket
        |> put_flash(:info, "Subtitle file deleted")
      else
        _ ->
          socket
          |> put_flash(:error, "Unable to delete the subtitle file")
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :subtitle, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    asset_id = socket.assigns.asset_lease.asset.id

    socket =
      with :ok <- UploadProcessor.create_uploads_base_path(),
           {:ok, uploaded_file_path} <- UploadProcessor.get_uploaded_entries(socket, :subtitle),
           {:ok, subtitle_file_details} <-
             UploadProcessor.get_subtitle_file_details(socket, uploaded_file_path),
           :ok <- UploadProcessor.check_for_uploaded_subtitle_file_type(subtitle_file_details),
           subtitle_file_dest = AssetSubtitle.asset_subtitle_base_path(asset_id),
           subtitle_file = Path.join([subtitle_file_dest, subtitle_file_details["name"]]),
           {:ok, _} <-
             AssetSubtitle.write_data_file(
               subtitle_file_details["file_path"],
               subtitle_file,
               subtitle_file_dest
             ),
           asset_subtitle_params =
             subtitle_file_details
             |> Map.put("asset_id", asset_id),
           {:ok, _asset_subtitle_struct} <- AssetSubtitle.create(asset_subtitle_params) do
        socket
        |> put_flash(:info, "Uploaded Successfully")
      else
        {:error, reason} ->
          Logger.error("Error while uploading the asset subtitle file: #{inspect(reason)}")

          socket
          |> put_flash(:error, inspect(reason))
      end

    {:noreply, socket}
  end

  def handle_event("update_language", %{"asset_subtitle" => asset_subtitle_map}, socket) do
    {asset_subtitle_id, asset_subtitle_params} = Map.pop(asset_subtitle_map, "id")

    case AssetSubtitle.update(asset_subtitle_id, asset_subtitle_params) do
      {:ok, _updated_asset_subtitle} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("sync_with_mv_asset", _, socket) do
    asset_struct = socket.assigns.asset_lease.asset
    mv_token = socket.assigns.mv_token
    download_params = %{asset_struct: asset_struct, mv_token: mv_token}
    AssetSubtitleDownloader.add_asset_subtitle_download_params(download_params)
    {:noreply, socket}
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
        |> push_navigate(to: Routes.asset_index_path(socket, :index))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:asset_subtitle_created, asset_subtitle}, socket) do
    asset_subtitles = AssetSubtitle.query_by_asset(asset_subtitle.asset_id)
    {:noreply, socket |> assign(asset_subtitles: asset_subtitles)}
  end

  def handle_info({:asset_subtitle_updated, asset_subtitle}, socket) do
    asset_subtitles = AssetSubtitle.query_by_asset(asset_subtitle.asset_id)

    socket =
      socket
      |> put_flash(:info, "Asset subtitle updated successfully")
      |> assign(asset_subtitles: asset_subtitles)

    {:noreply, socket}
  end

  def handle_info({:asset_subtitle_deleted, asset_subtitle}, socket) do
    asset_subtitles = AssetSubtitle.query_by_asset(asset_subtitle.asset_id)

    socket =
      socket
      |> put_flash(:info, "Asset subtitle deleted successfully")
      |> assign(asset_subtitles: asset_subtitles)

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

  defp render_media_display(assigns) do
    normalised_media_type = Asset.normalized_media_type(assigns.asset.media_type)

    case normalised_media_type do
      :audio ->
        ~H"""
        <ShowAudio.render source = {Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
          data_source={@asset.static_url}/>
        """

      :video ->
        ~H"""
        <ShowVideo.render data_source={@asset.static_url} />
        """

      :image ->
        ~H"""
        <ShowImage.render source={@asset.static_url} />
        """
    end
  end

  defp render_asset_stats(assigns) do
    normalised_media_type = Asset.normalized_media_type(assigns.asset.media_type)

    case normalised_media_type do
      :audio ->
        ~H"""
          <Stat.render title="Size" value= {get_file_size(@asset.attributes)} unit="MB"/>
          <Stat.render title="Duration" value= {get_duration(@asset.attributes)} unit="Sec"/>
          <Stat.render title="Status" value={@asset.status} />
          <Stat.render title="Media Type" value= {@asset.media_type} />
        """

      :video ->
        ~H"""
          <Stat.render title="Width" value= {get_width(@asset.attributes)} unit="px"/>
          <Stat.render title="Height" value= {get_height(@asset.attributes)} unit="px"/>
          <Stat.render title="Size" value= {get_file_size(@asset.attributes)} unit="MB"/>
          <Stat.render title="Duration" value= {get_duration(@asset.attributes)} unit="Sec"/>
          <Stat.render title="Status" value={@asset.status} />
          <Stat.render title="Media Type" value= {@asset.media_type} />
        """

      :image ->
        ~H"""
          <Stat.render title="Width" value= {get_width(@asset.attributes)} unit="px"/>
          <Stat.render title="Height" value= {get_height(@asset.attributes)} unit="px"/>
          <Stat.render title="Size" value= {get_file_size(@asset.attributes)} unit="MB"/>
          <Stat.render title="Status" value={@asset.status} />
          <Stat.render title="Media Type" value= {@asset.media_type} />
        """
    end
  end

  defp render_subtitle_header_buttons(nil, uploads) do
    [
      {
        :uploads,
        label: "Upload", uploads: uploads.subtitle, level: :secondary, type: :submit
      }
    ]
  end

  defp render_subtitle_header_buttons(_mv_asset_key, _) do
    [
      {
        :sync_with_mv_asset,
        label: "Sync with MediaVerse", level: :secondary, type: :click
      }
    ]
  end
end

defmodule Darth.AssetProcessor.AssetSubtitleDownloader do
  use GenServer
  require Logger
  alias Darth.MvApiClient
  alias Darth.Controller.{Asset, AssetSubtitle}
  alias DarthWeb.SaveFile

  @name {:global, __MODULE__}
  # Client
  def start_link([]) do
    GenServer.start_link(__MODULE__, %{queue: :queue.new(), processing: nil}, name: @name)
  end

  def add_asset_subtitle_download_params(%{asset_struct: asset_struct} = download_params) do
    if Asset.is_audio_or_video_asset?(asset_struct.media_type) do
      GenServer.cast(@name, {:add, download_params})
    else
      :error
    end
  end

  # Server (callbacks)
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:add, download_params}, %{queue: queue} = state) do
    new_state = %{state | queue: :queue.in(download_params, queue)}
    GenServer.cast(@name, :run)
    {:noreply, new_state}
  end

  # when nothing is processing right now start a new download
  def handle_cast(:run, %{queue: queue, processing: processing} = state)
      when is_nil(processing) do
    case :queue.out(queue) do
      {:empty, {[], []}} ->
        {:noreply, state}

      {{:value, download_params}, new_queue} ->
        new_state = %{state | queue: new_queue, processing: download_params}
        GenServer.cast(@name, {:download, download_params})
        {:noreply, new_state}
    end
  end

  # if something is processing, skip new download
  def handle_cast(:run, state) do
    {:noreply, state}
  end

  def handle_cast({:download, download_params}, state) do
    download_subtitle_file(download_params)

    new_state = %{state | processing: nil}
    GenServer.cast(@name, :run)
    {:noreply, new_state}
  end

  defp download_subtitle_file(asset_params) do
    mv_token = asset_params.mv_token
    asset_struct = asset_params.asset_struct

    case MvApiClient.fetch_asset_subtitles(
           asset_struct.mv_node,
           mv_token,
           asset_struct.mv_asset_key
         ) do
      {:ok, []} ->
        :ok

      {:ok, asset_subtitles} ->
        download_asset_subtitles(mv_token, asset_subtitles, asset_struct)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse while fetching subtitles: #{inspect(reason)}")

      err ->
        Logger.error("Custom error message from MediaVerse while fetching subtitles: #{inspect(err)}")
    end
  end

  defp download_asset_subtitles(mv_token, asset_subtitles, asset_struct) do
    asset_subtitle_base_path = AssetSubtitle.asset_subtitle_base_path(asset_struct.id)

    if create_asset_subtitle_base_path(asset_subtitle_base_path) == :ok do
      Enum.each(asset_subtitles, fn asset_subtitle ->
        # Filename is not returned from the MediaVerse.
        #  Constructing the filename as follows.
        #  Fetching only srt files from mediaverse therefore hardcoded as .srt
        asset_subtitle_filename = "subtitle_#{Map.get(asset_subtitle, "language")}.srt"
        asset_id = asset_struct.id
        asset_subtitle_language = Map.get(asset_subtitle, "language")
        version = Map.get(asset_subtitle, "version")
        download_url = Map.get(asset_subtitle, "externalFileUrl")
        mv_token = mv_token
        asset_subtitle_file_path = Path.join([asset_subtitle_base_path, asset_subtitle_filename])

        with {:ok, response} <- MvApiClient.download_asset_subtitle(mv_token, download_url),
             {:ok, file} <- File.open(asset_subtitle_file_path, [:write, :binary]),
             :ok <- SaveFile.save_file(file, response),
             asset_subtitle_params = %{
               "name" => asset_subtitle_filename,
               "version" => version,
               "static_path" => asset_subtitle_file_path,
               "language" => asset_subtitle_language,
               "asset_id" => asset_id
             },
             {:ok, _asset_subtitle_struct} <- AssetSubtitle.create(asset_subtitle_params) do
          :ok
        else
          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("Custom error message from MediaVerse when downloading asset subtitle
                (HTTPoison error): #{inspect(reason)}")

            delete_incomplete_download(asset_subtitle_file_path)
            {:error, "MediaVerse API error"}

          # File creation error
          {:error, :enoent} ->
            Logger.error("Custom error message from MediaVerse: Cannot open file")
            {:error, "Cannot create file"}

          # General error handling
          {:error, reason} ->
            Logger.error("Custom error message from MediaVerse (General error): #{inspect(reason)}")

            {:error, inspect(reason)}
        end
      end)
    end
  end

  defp create_asset_subtitle_base_path(asset_subtitle_base_path) do
    case File.mkdir_p(asset_subtitle_base_path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Error while creating the asset subtitle base path directory: #{inspect(reason)}")

        :error
    end
  end

  defp delete_incomplete_download(asset_subtitle_path) do
    case File.rm(asset_subtitle_path) do
      :ok ->
        Logger.info("Deleted the incompletely downloaded file")

      {:error, reason} ->
        Logger.warning("Unable to delete the incompletely downloaded file: #{inspect(reason)}")
    end
  end
end

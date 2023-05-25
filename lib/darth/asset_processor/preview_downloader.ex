defmodule Darth.AssetProcessor.PreviewDownloader do
  use GenServer
  require Logger
  alias Darth.{Controller.Asset, MvApiClient}
  alias DarthWeb.SaveFile

  @name {:global, __MODULE__}
  # Client
  def start_link([]) do
    GenServer.start_link(__MODULE__, %{queue: :queue.new(), processing: nil}, name: @name)
  end

  def add_preview_download_params(download_params) do
    GenServer.cast(@name, {:add, download_params})
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
    download_preview_asset(download_params)

    new_state = %{state | processing: nil}
    GenServer.cast(@name, :run)
    {:noreply, new_state}
  end

  def asset_file_path(preview_link_key, original_filename) do
    download_path = Application.get_env(:darth, :mv_asset_preview_download_path)
    app_path = Application.app_dir(:darth, download_path)
    Path.join([app_path, preview_link_key, original_filename])
  end

  def add_to_preview_downloader(assets, mv_node, mv_token) do
    for asset <- assets do
      filename = Map.get(asset, "originalFilename")
      asset_previewlink_key = Map.get(asset, "previewLinkKey")
      file_path = asset_file_path(asset_previewlink_key, filename)

      if File.exists?(file_path) do
        :ok
      else
        download_params = %{
          mv_asset_previewlink_key: asset_previewlink_key,
          mv_node: mv_node,
          mv_token: mv_token,
          mv_asset_filename: filename
        }

        add_preview_download_params(download_params)
      end
    end
  end

  defp download_preview_asset(download_params) do
    mv_asset_filename = download_params.mv_asset_filename
    mv_asset_previewlink_key = download_params.mv_asset_previewlink_key

    with {:ok, response} <-
           MvApiClient.download_preview_asset(
             download_params.mv_node,
             download_params.mv_token,
             download_params.mv_asset_previewlink_key
           ),
         {:ok, file} <- Asset.create_preview_file(mv_asset_filename, mv_asset_previewlink_key),
         :ok <- SaveFile.save_file(file, response),
         :ok <- Phoenix.PubSub.broadcast(Darth.PubSub, "asset_previews", {:asset_preview_downloaded}) do
      :ok
    else
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse (HTTPoison error): #{inspect(reason)}")
        {:ok, preview_asset_path} = Asset.create_preview_asset_path(mv_asset_filename, mv_asset_previewlink_key)
        delete_incomplete_download(preview_asset_path)
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
  end

  defp delete_incomplete_download(preview_asset_path) do
    case File.rm(preview_asset_path) do
      :ok ->
        Logger.info("Deleted the incompletely downloaded file")

      {:error, reason} ->
        Logger.warning("Unable to delete the incompletely downloaded file: #{inspect(reason)}")
    end
  end
end

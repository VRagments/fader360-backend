defmodule Darth.AssetProcessor.Downloader do
  use GenServer
  require Logger
  alias Darth.{Controller.Asset, MvApiClient}

  @name {:global, __MODULE__}
  # Client
  def start_link([]) do
    GenServer.start_link(__MODULE__, %{queue: :queue.new(), processing: nil}, name: @name)
  end

  def add_download_params(download_params) do
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
    update_asset_status(download_params.asset_struct.id, "download_started")
    download(download_params)

    new_state = %{state | processing: nil}
    GenServer.cast(@name, :run)
    {:noreply, new_state}
  end

  def download(download_params) do
    with {:ok, response} <-
           MvApiClient.download_asset(
             download_params.mv_node,
             download_params.mv_token,
             download_params.mv_asset_deeplink_key
           ),
         {:ok, file} <- Asset.create_file(download_params.mv_asset_filename),
         :ok <- Asset.save_file(file, response),
         {:ok, mv_asset_file_path} = Asset.create_current_asset_path(download_params.mv_asset_filename),
         params = Asset.build_asset_params(download_params, mv_asset_file_path),
         {:ok, asset_struct} <- Asset.init(download_params.asset_struct, params, true) do
      update_asset_status(download_params.asset_struct.id, "downloaded_successfully")
      {:ok, asset_struct}
    else
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse (HTTPoison error): #{inspect(reason)}")
        {:ok, current_asset_path} = Asset.create_current_asset_path(download_params.mv_asset_filename)
        delete_incomplete_download(current_asset_path)
        update_asset_status(download_params.asset_struct.id, "download_failed")
        {:error, "MediaVerse API error"}

      # File creation error
      {:error, :enoent} ->
        Logger.error("Custom error message from MediaVerse: Cannot open file")
        update_asset_status(download_params.asset_struct.id, "download_failed")
        {:error, "Cannot create file"}

      # General error handling
      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse (General error): #{inspect(reason)}")
        update_asset_status(download_params.asset_struct.id, "download_failed")
        {:error, inspect(reason)}
    end
  end

  defp delete_incomplete_download(current_asset_path) do
    case File.rm(current_asset_path) do
      :ok ->
        Logger.info("Deleted the incompletely downloaded file")

      {:error, reason} ->
        Logger.warning("Unable to delete the incompletely downloaded file: #{inspect(reason)}")
    end
  end

  defp update_asset_status(asset_id, status) do
    case Asset.update_status(asset_id, status) do
      {:ok, _asset} ->
        :ok

      {:error, reason} ->
        Logger.error(:error, "Error while updating the asset status when asset download failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

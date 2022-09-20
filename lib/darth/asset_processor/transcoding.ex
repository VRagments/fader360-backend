defmodule Darth.AssetProcessor.Transcoding do
  use GenServer

  require Logger

  alias Darth.AssetProcessor
  alias Darth.AssetProcessor.Helpers
  alias Darth.Controller

  @init_state %{asset_id: "", port: nil}

  #
  # EXTERNAL FUNCTIONS
  #

  @doc """
  Start transcoding genserver for `asset_id`.
  """
  def start_link(asset_id) do
    GenServer.start_link(__MODULE__, asset_id)
  end

  @doc """
  Cancel current transcoding job.
  """
  def cancel(pid) do
    GenServer.cast(pid, :cancel)
  end

  #
  # CALLBACKS
  #

  def init(asset_id) do
    GenServer.cast(self(), :run)
    {:ok, %{@init_state | asset_id: asset_id}}
  end

  def handle_cast(:run, %{asset_id: asset_id} = state) do
    # Execute transcoding job.
    with {:ok, asset} <- Controller.Asset.update_status(asset_id, "transcoding_started"),
         {:ok, port} <- run_asset(asset) do
      {:noreply, %{state | port: port}}
    else
      {:error, reason} ->
        AssetProcessor.transcoding_failed(asset_id, reason)
        {:stop, :normal, state}
    end
  end

  def handle_cast(:cancel, state) do
    # Handle cancel command by closing port and removing state.
    {:stop, :normal, state}
  end

  def handle_info({port, {:exit_status, 0}}, %{asset_id: asset_id} = state) do
    # Transcoding finished with `exit_status`.
    if port == state.port do
      AssetProcessor.transcoding_done(asset_id)
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({port, {:exit_status, exit_status}}, %{asset_id: asset_id} = state) do
    if port == state.port do
      AssetProcessor.transcoding_failed(asset_id, "port exited with #{inspect(exit_status)}")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(_msg, state) do
    # Handle port operations stdout data.
    # We ignore all stdout content for the port
    {:noreply, state}
  end

  @doc """
  Cleanup operations on shutdown.
  """
  def terminate(_reason, %{port: port}) do
    Helpers.close_port(port)
  end

  #
  # INTERNAL FUNCTIONS
  #

  @default_transcoding_scripts %{
    audio: "./apps/**/transcode_audio.sh",
    image: "./apps/**/transcode_image.sh",
    video: "./apps/**/transcode_video.sh"
  }
  @video_profiles Application.compile_env(:darth, :transcoding_video_profiles, "720_1")
  defp run_asset(%{media_type: media_type} = asset) do
    norm_media_type = Controller.Asset.normalized_media_type(media_type)

    script_path = Application.get_env(:darth, :transcoding_scripts, @default_transcoding_scripts)[norm_media_type]

    [script] = Path.wildcard(script_path)
    %{data_filename: data_filename, static_filename: static_filename, static_path: static_path} = asset
    input_file = ~s(#{static_path}/#{data_filename})

    nr_threads = Application.get_env(:darth, :transcoding_threads, :erlang.system_info(:logical_processors))

    extra_args =
      case norm_media_type do
        :video ->
          ["-t", "#{nr_threads}", "-p", "#{@video_profiles}"]

        :audio ->
          ["-t", "#{nr_threads}"]

        _ ->
          []
      end

    case System.find_executable("bash") do
      nil ->
        {:error, "Couldn't find bash executable"}

      bin ->
        c_args = ["#{script}", "-f", "#{input_file}", "-o", "#{static_path}", "-m", "#{static_filename}"]
        args = ["-c", Enum.join(c_args ++ extra_args, " ")]
        options = [:exit_status, parallelism: true, args: args]
        _ = Logger.debug(fn -> "Executing: #{bin} with #{inspect(options)}" end)

        try do
          port = Port.open({:spawn_executable, bin}, options)
          {:ok, port}
        catch
          err ->
            err
        end
    end
  end
end

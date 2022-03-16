defmodule Darth.AssetProcessor.Analyzing do
  use GenServer

  require Logger

  alias Darth.AssetProcessor
  alias Darth.AssetProcessor.Helpers
  alias Darth.Controller

  import SweetXml, only: [sigil_x: 2]

  @init_state %{asset_id: "", data: [], port: nil}

  #
  # EXTERNAL FUNCTIONS
  #

  @doc """
  Start analyzing genserver for `asset_id`.
  """
  def start_link(asset_id) do
    GenServer.start_link(__MODULE__, asset_id)
  end

  @doc """
  Cancel current analyzing job.
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
    # Prepare metadata retrieval.
    with {:ok, asset} <- Controller.Asset.update_status(asset_id, "analyzing_started"),
         input_file = "#{asset.static_path}/#{asset.data_filename}",
         {:ok, mime_type} <- Darth.AssetFile.Helpers.mime_type(input_file),
         {:ok, updated_asset} <- Controller.Asset.update(asset_id, %{media_type: mime_type}, false, true),
         {:ok, res} <- analyze(updated_asset) do
      if is_port(res) do
        {:noreply, %{state | port: res}}
      else
        check_analysis(0, %{state | data: res})
      end
    else
      {:error, reason} ->
        AssetProcessor.analyzing_failed(asset_id, reason)
        {:stop, :normal, state}
    end
  end

  def handle_cast(:cancel, state) do
    # Handle cancel command by closing port and removing state.
    {:stop, :normal, state}
  end

  def handle_info({port, {:data, data}}, state) do
    # Port operation's stdout `data` is gathered into state.
    if port == state.port do
      {:noreply, %{state | data: state.data ++ data}}
    else
      {:noreply, state}
    end
  end

  def handle_info({port, {:exit_status, exit_status}}, state) do
    # Port operation finished with `exit_status`.
    if port == state.port do
      check_analysis(exit_status, state)
    else
      {:noreply, state}
    end
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

  defp analyze(%{media_type: media_type} = asset) do
    case Controller.Asset.normalized_media_type(media_type) do
      :image ->
        if Controller.Asset.svg?(asset) do
          use_xml(asset)
        else
          use_convert(asset)
        end

      :audio ->
        use_ffprobe(asset)

      :video ->
        use_ffprobe(asset)

      nil ->
        {:error, "Failed normalizing media type for #{inspect(media_type)}"}
    end
  end

  @svg_default_width 100
  @svg_default_height 100
  defp use_xml(asset) do
    %{data_filename: data_filename, static_path: static_path} = asset
    data_file = "#{static_path}/#{data_filename}"

    with {:ok, file} <- File.read(data_file) do
      width_str = SweetXml.xpath(file, ~x"/svg/@width"s)
      height_str = SweetXml.xpath(file, ~x"/svg/@height"s)
      viewbox = SweetXml.xpath(file, ~x"/svg/@viewBox"s)

      {viewbox_width_str, viewbox_height_str} =
        case String.split(viewbox, " ") do
          [_, _, w, h] ->
            {w, h}

          _ ->
            {"", ""}
        end

      viewbox_width = parse_integer(viewbox_width_str, @svg_default_width)
      viewbox_height = parse_integer(viewbox_height_str, @svg_default_height)
      width = parse_integer(width_str, viewbox_width)
      height = parse_integer(height_str, viewbox_height)
      # we pack the data like ImageMagick would do
      data = [
        %{
          image: %{
            geometry: %{
              width: width,
              height: height
            }
          }
        }
      ]

      Jason.encode(data)
    end
  end

  defp parse_integer(str, default) do
    case Integer.parse(str) do
      {int, _} ->
        int

      :error ->
        default
    end
  end

  defp use_convert(asset) do
    case System.find_executable("convert") do
      nil ->
        {:error, "Couldn't find imagemagick's convert executable"}

      bin ->
        %{data_filename: data_filename, static_path: static_path} = asset
        data_file = "#{static_path}/#{data_filename}"
        # INFO
        # using -ping is significantly faster.
        # However the info returned is slightly inaccurate.
        # Also the output json throws a parsing error.
        args = ["-auto-orient", data_file, "json:"]
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

  defp use_ffprobe(asset) do
    case System.find_executable("ffprobe") do
      nil ->
        {:error, "Couldn't find ffmpeg's ffprobe executable"}

      bin ->
        %{data_filename: data_filename, static_path: static_path} = asset
        data_file = "#{static_path}/#{data_filename}"
        args = ["-v", "fatal", "-show_streams", "-show_format", "-print_format", "json", data_file]
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

  # Image/Media analysis finished successfully.
  defp check_analysis(0, %{asset_id: asset_id, data: data} = state) do
    AssetProcessor.analyzing_done(asset_id, data)
    {:stop, :normal, state}
  end

  # Media analysis failed.
  defp check_analysis(exit_status, %{asset_id: asset_id} = state) do
    reason = "port exit_status #{exit_status}"
    AssetProcessor.analyzing_failed(asset_id, reason)
    {:stop, :normal, state}
  end
end

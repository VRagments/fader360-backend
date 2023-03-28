defmodule Darth.AssetProcessor do
  use GenServer

  require Logger

  alias Darth.AssetFile
  alias Darth.AssetFile.Helpers
  alias Darth.AssetProcessor.Analyser
  alias Darth.AssetProcessor.Transcoder
  alias Darth.Controller

  @convert_wrong_json ~r/: [-]?nan/

  # available job targets: :analyzing, :transcoding, :analyzing_transcoding
  @init_state %{
    # asset_id => target
    jobs: %{},
    # asset_id => pid
    active: %{analyzing: %{}, transcoding: %{}},
    # queue<asset_id>
    queued: %{analyzing: :queue.new(), transcoding: :queue.new()}
  }

  @finishable_target %{analyzing: [:analyzing], transcoding: [:analyzing_transcoding, :transcoding]}

  #
  # EXTERNAL FUNCTIONS
  #

  @doc """
  Start asset processing genserver.
  It takes care of distributing asset jobs to analyzing and transcoding.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, @init_state, name: __MODULE__)
  end

  @doc """
  Signal to the asset processor that the analyze step for the given asset id has failed.
  """
  def analyzing_failed(asset_id, error) do
    GenServer.cast(__MODULE__, {:analyzing_failed, asset_id, error})
  end

  @doc """
  Signal to the asset processor that the analyze step for the given asset id has succeeded.
  """
  def analyzing_done(asset_id, data) do
    GenServer.cast(__MODULE__, {:analyzing_done, asset_id, data})
  end

  @doc """
  Signal to the asset processor that the transcoding step for the given asset id has failed.
  """
  def transcoding_failed(asset_id, error) do
    GenServer.cast(__MODULE__, {:transcoding_failed, asset_id, error})
  end

  @doc """
  Signal to the asset processor that the transcoding step for the given asset id has succeeded.
  """
  def transcoding_done(asset_id) do
    GenServer.cast(__MODULE__, {:transcoding_done, asset_id})
  end

  #
  # CALLBACKS
  #

  @doc """
  Initialize analyzing and transcoding genservers.
  """
  def init(state) do
    Process.flag(:trap_exit, true)
    :ok = Phoenix.PubSub.subscribe(Darth.PubSub, "assets")
    {:ok, state}
  end

  def handle_cast({:analyzing_failed, asset_id, error}, state) do
    # Incoming msg when analyzing job for `asset_id` has finished.
    _ = Logger.error(fn -> "Error while analyzing asset #{asset_id}: #{inspect(error)}" end)
    Controller.Asset.update_status(asset_id, "analyzing_failed")
    {:noreply, finish_job(state, :analyzing, asset_id)}
  end

  def handle_cast({:analyzing_done, asset_id, data}, state) do
    target = get_in(state, [:jobs, asset_id])

    asset_status =
      if target in @finishable_target[:analyzing] do
        "ready"
      else
        "analyzing_finished"
      end

    str_data = to_string(data)

    try do
      apply_metadata(asset_id, str_data, asset_status)
    catch
      kind, value ->
        _ =
          Logger.error(fn ->
            "#{inspect(kind)} while applying metadata to asset #{asset_id}: #{inspect(value)} on #{inspect(__STACKTRACE__)}"
          end)

        Controller.Asset.update_status(asset_id, "analyzing_failed")
    end

    {:noreply, finish_job(state, :analyzing, asset_id)}
  end

  def handle_cast({:transcoding_failed, asset_id, error}, state) do
    # Incoming msg when transcoding job for `asset_id` has finished.
    _ = Logger.error(fn -> "Error while transcoding asset #{asset_id}: #{inspect(error)}" end)
    Controller.Asset.update_status(asset_id, "transcoding_failed")
    {:noreply, finish_job(state, :transcoding, asset_id)}
  end

  def handle_cast({:transcoding_done, asset_id}, state) do
    Controller.Asset.update_status(asset_id, "ready")
    _ = Phoenix.PubSub.broadcast(Darth.PubSub, "assets", {:asset_transcoding_done, asset_id})
    {:noreply, finish_job(state, :transcoding, asset_id)}
  end

  def handle_cast(msg, state) do
    _ = Logger.debug(fn -> "Received unhandled cast message #{inspect(msg)}" end)
    {:noreply, state}
  end

  def handle_call(msg, from, state) do
    _ = Logger.debug(fn -> "Received unhandled call message #{inspect(msg)} from #{inspect(from)}" end)
    {:noreply, state}
  end

  def handle_info({:asset_analyze_transcode, asset_id}, state) do
    # Incoming msg when asset with `asset_id` should run analyzing followed by transcoding.
    new_state =
      state
      |> create_job(:analyzing_transcoding, asset_id)
      |> start_job(:analyzing, asset_id)

    {:noreply, new_state}
  end

  def handle_info({:asset_analyze, asset_id}, state) do
    # Incoming msg when asset with `asset_id` should rerun analyzing.
    new_state =
      state
      |> create_job(:analyzing, asset_id)
      |> start_job(:analyzing, asset_id)

    {:noreply, new_state}
  end

  def handle_info({:asset_transcode, asset_id}, state) do
    # Incoming msg when asset with `asset_id` should rerun transcoding.
    new_state =
      state
      |> create_job(:transcoding, asset_id)
      |> start_job(:transcoding, asset_id)

    {:noreply, new_state}
  end

  def handle_info({:asset_analyzing_done, _asset_id}, state) do
    # Incoming msg when asset with `asset_id` finished analyzing. Will start/queue transcoding job.
    {:noreply, state}
  end

  def handle_info({:asset_transcoding_done, _asset_id}, state) do
    # Incoming msg when asset with `asset_id` finished transcoding.
    {:noreply, state}
  end

  def handle_info({:asset_updated, _asset}, state) do
    # Incoming msg when asset propagated an update. Currently this results in noop.
    # TODO: only re-transcode if data changed, see Asset.data_changed?
    {:noreply, state}
  end

  def handle_info({:asset_deleted, asset}, state) do
    # Incoming msg when `asset` was deleted. Will remove the assets folder and cancel running/queued jobs.
    # delete asset_id in active, queued and jobs
    {_, new_state} =
      [:analyzing, :transcoding]
      |> Enum.reduce(state, fn job_type, acc ->
        queue = acc |> get_in([:queued, job_type])
        new_queue = :queue.filter(&(&1.id != asset.id), queue)
        acc |> put_in([:queued, job_type], new_queue)
        {_, u_acc} = acc |> pop_in([:active, job_type, asset.id])
        u_acc
      end)
      |> pop_in([:jobs, asset.id])

    # delete local directory, if it still exists
    _ =
      case asset.static_path do
        nil ->
          _ = Logger.error(fn -> "Can't delete empty path for asset #{asset.id}" end)

        "/" ->
          _ = Logger.error(fn -> "Won't delete root path for asset #{asset.id}" end)

        _ ->
          with true <- File.dir?(asset.static_path),
               [] <- delete_folder(asset.static_path) do
            _ = Logger.debug(fn -> "Deleted all files for asset #{asset.id} at #{asset.static_path}" end)
            :ok
          else
            false ->
              _ = Logger.error(fn -> "Error while deleting files for asset #{asset.id}: directory doesn't exist
                #{asset.static_path}" end)

            errors ->
              _ = Logger.error(fn -> "Error while deleting files for asset #{asset.id}: #{errors |> inspect}" end)
          end
      end

    {:noreply, new_state}
  end

  # We do not care about proper process exits
  def handle_info({:EXIT, _pid, :normal}, state), do: {:noreply, state}

  def handle_info({:EXIT, pid, reason}, state) do
    _ =
      Logger.debug(fn ->
        "Received exit signal #{inspect(reason)} by process #{inspect(pid)}, ignoring the signal"
      end)

    {:noreply, state}
  end

  def handle_info(msg, state) do
    _ = Logger.debug(fn -> "Received unhandled info message #{inspect(msg)}" end)
    {:noreply, state}
  end

  @doc """
  Cleanup operations on shutdown.
  """
  def terminate(reason, state) do
    _ =
      Logger.debug(fn ->
        "#{__MODULE__} terminating with reason #{inspect(reason)} and state: #{inspect(state)}"
      end)

    case Phoenix.PubSub.unsubscribe(Darth.PubSub, "assets") do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error(fn -> "Error while unsubscribing #{inspect(reason)}" end)
    end
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp apply_metadata(asset_id, json_data, asset_status) do
    with sanitized_json = Regex.replace(@convert_wrong_json, json_data, ": 0"),
         {:ok, metadata} <- Jason.decode(sanitized_json),
         {:ok, asset} <- Controller.Asset.read(asset_id),
         {:ok, stat} <- stat_original(asset),
         {:ok, attributes} <- determine_attributes(asset.media_type, metadata, stat),
         {:ok, raw_metadata} <- determine_raw_metadata(sanitized_json, stat),
         params = %{
           "attributes" => asset.attributes |> Map.merge(attributes),
           "status" => asset_status,
           "raw_metadata" => asset.raw_metadata |> Map.merge(raw_metadata)
         },
         attributed_asset = asset |> Map.merge(params),
         paths = attributed_asset |> Controller.Asset.generate_paths(),
         changes = params |> Map.merge(paths),
         {:ok, _a} <- Controller.Asset.update(asset_id, changes, false) do
      Phoenix.PubSub.broadcast(Darth.PubSub, "assets", {:asset_analyzing_done, asset_id})
    else
      err ->
        {:ok, asset} = Controller.Asset.read(asset_id)

        _ =
          Logger.error(fn ->
            "Error while applying metadata for asset #{asset_id} #{original_path(asset)}: #{inspect(err)}"
          end)

        Controller.Asset.update_status(asset_id, "analyzing_failed")
    end
  end

  defp create_job(state, job_type, asset_id), do: state |> put_in([:jobs, asset_id], job_type)

  defp start_job(state, job_type, asset_id) do
    new_state = state |> stop_running(asset_id)
    active = new_state |> get_in([:active, job_type])
    # determine if we have room to start the job or if we just queue it
    if Enum.count(active) < parallel_jobs(job_type) do
      run_job(new_state, job_type, asset_id)
    else
      queue = get_in(new_state, [:queued, job_type])
      put_in(new_state, [:queued, job_type], :queue.in(asset_id, queue))
    end
  end

  defp finish_job(state, job_type, asset_id) do
    # remove from active
    {_, next_state} = pop_in(state, [:active, job_type, asset_id])

    # remove from jobs if job has reached its final step or trigger next job phase
    target = get_in(state, [:jobs, asset_id])

    next_state =
      if target in @finishable_target[job_type] do
        {_, next_state} = pop_in(next_state, [:jobs, asset_id])
        next_state
      else
        start_next_phase(next_state, job_type, asset_id)
      end

    # trigger next queued job
    start_queued_job(next_state, job_type)
  end

  defp start_next_phase(state, finished_phase, asset_id) do
    target = get_in(state, [:jobs, asset_id])

    if target == :analyzing_transcoding and finished_phase == :analyzing do
      start_job(state, :transcoding, asset_id)
    else
      state
    end
  end

  defp start_queued_job(state, job_type) do
    queue = get_in(state, [:queued, job_type])

    if :queue.is_empty(queue) do
      state
    else
      {{:value, asset_id}, new_queue} = :queue.out(queue)

      state
      |> put_in([:queued, job_type], new_queue)
      |> start_job(job_type, asset_id)
    end
  end

  defp stop_running(%{active: %{analyzing: act_a, transcoding: act_t}} = state, asset_id) do
    stop_job_processor(:analyzing, act_a[asset_id])
    stop_job_processor(:transcoding, act_t[asset_id])
    {_, next_state} = state |> pop_in([:active, :analyzing, asset_id])
    {_, next_state} = next_state |> pop_in([:active, :transcoding, asset_id])
    next_state
  end

  defp stop_job_processor(_, nil), do: :ok
  defp stop_job_processor(:analyzing, pid), do: Analyser.cancel(pid)
  defp stop_job_processor(:transcoding, pid), do: Transcoder.cancel(pid)

  @parallel_analyzers Application.compile_env(:darth, :parallel_analyzers, 4)
  @parallel_transcoders Application.compile_env(:darth, :parallel_transcoders, 2)
  defp parallel_jobs(:analyzing), do: @parallel_analyzers
  defp parallel_jobs(:transcoding), do: @parallel_transcoders

  defp run_job(state, job_type, asset_id) do
    with {:ok, pid} <- start_job_processor(job_type, asset_id) do
      put_in(state, [:active, job_type, asset_id], pid)
    else
      {:error, reason} ->
        _ = Logger.error(fn -> "Error while starting #{job_type} processor: #{inspect(reason)}" end)
        state
    end
  end

  defp start_job_processor(:analyzing, asset_id), do: Analyser.start_link(asset_id)
  defp start_job_processor(:transcoding, asset_id), do: Transcoder.start_link(asset_id)

  defp original_path(%{data_filename: data_filename, static_path: static_path}) do
    "#{static_path}/#{data_filename}"
  end

  defp stat_original(asset) do
    with data_file <- original_path(asset),
         {:ok, stat} <- File.stat(data_file),
         {:ok, atime} <- NaiveDateTime.from_erl(stat.atime),
         {:ok, ctime} <- NaiveDateTime.from_erl(stat.ctime),
         {:ok, mtime} <- NaiveDateTime.from_erl(stat.mtime) do
      {:ok, stat |> Map.merge(%{atime: atime, ctime: ctime, mtime: mtime})}
    end
  end

  defp determine_attributes(media_type, metadata, stat) do
    afile = Helpers.asset_file(media_type, metadata, stat)

    with {:ok, {width, height}} <- AssetFile.dimensions(afile),
         {:ok, duration} <- AssetFile.duration(afile),
         {:ok, file_size} <- AssetFile.file_size(afile),
         do: {:ok, %{duration: duration, file_size: file_size, height: height, width: width}}
  end

  defp determine_raw_metadata(json_data, stat) do
    with {:ok, json_stat} <- Map.from_struct(stat) |> Jason.encode(),
         do: {:ok, %{analysis: json_data, stat: json_stat}}
  end

  defp delete_folder(path) do
    errors =
      if File.dir?(path) do
        {:ok, files} = File.ls(path)

        Enum.reduce(files, [], fn f, acc ->
          case delete_folder(f) do
            [] ->
              acc

            other ->
              other ++ acc
          end
        end)
      else
        []
      end

    case File.rm_rf(path) do
      {:ok, _} ->
        errors

      {:error, reason, file} ->
        [{file, reason} | errors]
    end
  end
end

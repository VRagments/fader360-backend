defmodule Darth.Maintenance do
  @moduledoc false

  import Ecto.Query

  require Logger

  alias Darth.AssetFile
  alias Darth.Model.{Asset}
  alias Darth.{Repo, Controller}

  # Sometimes asset creation fails if we experienced problems with our media storage. This task finds these assets
  # and deletes them, since they are no use to the user.
  def delete_empty_assets() do
    Asset
    |> select([:id, :static_path, :data_filename, :status])
    |> where([a], a.status != "ready")
    |> Repo.all()
    |> Enum.filter(fn a ->
      data_path = Path.join(a.static_path, a.data_filename)

      case File.stat(data_path) do
        {:ok, %{size: 0}} ->
          true

        _ ->
          false
      end
    end)
    |> Enum.map(fn a -> {a.id, Controller.Asset.delete(a.id)} end)
  end

  # Sometimes users upload broken iOS videos, which can't be analyzed and played. This task finds these assets
  # and deletes them, since they are no use to the user.
  def delete_broken_quicktime_assets() do
    print_asset_ids = fn assets ->
      headers = [
        "Maintenance: #{length(assets)} Assets will be deleted",
        "idx | Asset id",
        "--------------"
      ]

      output =
        assets
        |> Enum.with_index(1)
        |> Enum.map(fn {a, idx} ->
          "#{idx} | #{a.id}"
        end)

      log_output = headers ++ output
      _ = log_output |> Enum.join("\n") |> Logger.info()
      assets
    end

    Asset
    |> select([:id, :static_path, :data_filename, :status])
    |> where([a], a.status != "ready")
    |> Repo.all()
    |> Enum.filter(fn a ->
      data_path = Path.join(a.static_path, a.data_filename)

      case AssetFile.Helpers.mime_type(data_path) do
        {:ok, "video/quicktime"} ->
          ffprobe_args = ["-v", "fatal", "-show_streams", "-show_format", "-print_format", "json", data_path]

          case System.cmd("ffprobe", ffprobe_args) do
            {_, 1} ->
              true

            _ ->
              _ = Logger.debug(fn -> "Failed quicktime asset #{a.id} seems to be usable" end)
              false
          end

        _ ->
          # We don't care about these assets here.
          false
      end
    end)
    |> print_asset_ids.()
    |> (fn assets ->
          if IO.gets("Proceed with cleanup? (Enter 'Yes') ") == "Yes\n" do
            res = Enum.map(assets, fn a -> {a.id, Controller.Asset.delete(a.id)} end)
            IO.puts("Cleanup finished")
            res
          else
            IO.puts("Aborting cleanup")
            []
          end
        end).()
  end

  # Ensure every asset's data_filename points to a file
  @spec fix_data_filenames() :: no_return
  def fix_data_filenames() do
    # > 4273 data_filename exists
    # 2506 path_data does not exists
    # 375 exising originals (last exenstion wrong) (e.g. mp4.m3u8)
    # 746   jpg -> jpeg originals (e.g. jpg.jpeg)
    # 1338 data_filenames not starting with `original_`
    # 47 files with false namings (special chars and so on)

    all_assets = Asset |> Repo.all()
    total_asset_count = length(all_assets)

    not_existing_data_filename =
      all_assets
      |> Enum.with_index(1)
      |> Enum.filter(fn {a, idx} ->
        _ =
          if rem(idx, 100) == 0 do
            Logger.info(fn -> "Maintenance: Checked file existance #{idx} of #{total_asset_count}" end)
          end

        path = Path.join(a.static_path, a.data_filename)

        not File.exists?(path)
      end)
      |> Enum.map(fn {a, _} -> a end)

    not_existing_data_filename_count = length(not_existing_data_filename)

    updated_data_filenames =
      not_existing_data_filename
      |> Enum.with_index(1)
      |> Enum.map(fn {a, idx} ->
        _ =
          if rem(idx, 100) == 0 do
            Logger.info(fn ->
              "Maintenance: Try replacing extension #{idx} of #{not_existing_data_filename_count}"
            end)
          end

        maybe_replacing_extension(a)
      end)

    {auto_moveable, manual} =
      Enum.reduce(updated_data_filenames, {[], []}, fn
        {:moved, _, _} = entry, {auto, manual} -> {[entry | auto], manual}
        entry, {auto, manual} -> {auto, [entry | manual]}
      end)

    _ = Logger.info(fn -> "Maintenance: #{length(auto_moveable)} updatable assets are moved to referenced location
      now" end)

    # move original files
    Enum.each(auto_moveable, fn {:moved, asset, path} -> update_data_filename(asset, path) end)

    # print remaining assets
    log_output =
      manual
      |> Enum.with_index(1)
      |> Enum.map(fn {{:noop, asset}, idx} ->
        %{id: id, static_path: static_path, data_filename: data_filename} = asset
        "#{idx} | #{id} | #{static_path} | #{data_filename}"
      end)

    log_output =
      [
        "Maintenance: #{length(manual)} remaining assets need manual update for originals",
        "idx | Asset id | static_path | data_filename(wrong)",
        "---------------------------------------------------"
      ] ++ log_output

    log_output |> Enum.join("\n") |> Logger.info()
  end

  # Check transcoded video and audio files if there original file is correct
  def print_incorrect_data_filenames do
    {errors, manual_commands} = determine_commands()

    print_assets = fn values, headers ->
      print_values =
        values
        |> Enum.with_index(1)
        |> Enum.map(fn {{asset, {_, output}}, idx} ->
          output =
            if is_list(output) do
              Enum.join(output, " ")
            else
              output
            end

          "#{idx} | #{asset.id} | #{asset.static_path} | #{output}"
        end)

      log_output = headers ++ print_values
      _ = log_output |> Enum.join("\n") |> Logger.info()
      :ok
    end

    print_assets.(manual_commands, [
      "Maintenance: #{length(manual_commands)} assets need manual transcoding commands",
      "idx | Asset id | static_path | command",
      "--------------------------------------"
    ])

    print_assets.(errors, [
      "Maintenance: #{length(errors)} assets fail evaluation",
      "idx | Asset id | static_path | reason",
      "--------------------------------------"
    ])
  end

  # libmp3lame not installed on application servers.
  # Run transcoding only on copy or libvorbis codec.
  def run_available_transcoders_on_incorrect_data_filenames do
    {_errors, manual_commands} = determine_commands()
    runnable = Enum.filter(manual_commands, fn {_, {_, cmd}} -> not Enum.member?(cmd, "libmp3lame") end)
    mp3lames = manual_commands -- runnable
    _ = Logger.info(fn -> "Maintenance: #{length(runnable)} transcoding operations executed" end)

    runnable
    |> Enum.with_index(1)
    |> Enum.each(fn {{%{id: id}, {_, command}}, idx} ->
      [bin | params] = command

      case System.cmd(bin, params) do
        {_, 0} ->
          Logger.info(fn -> "#{idx} | #{id} | :ok" end)

        {msg, code} ->
          Logger.error(fn ->
            "Maintenance: Error executing transcoding for #{inspect(id)}: #{inspect(msg)} (#{inspect(code)})"
          end)
      end
    end)

    [
      "#{length(mp3lames)} transcoding operation skipped",
      "Run Darth.Maintenance.print_incorrect_data_filenames to print them for manual transcoding"
    ]
    |> Enum.join("\n")
    |> Logger.info()
  end

  @doc """
  This function will look for videos which have been transcoded using only a single resolution by error.
  These videos will be re-transcoded.
  """
  def regenerate_single_resolution_videos(dryrun \\ true) do
    assets =
      Asset
      |> where([a], ilike(a.media_type, "video/%"))
      |> Repo.all()

    incomplete_assets =
      assets
      |> Enum.filter(&(Controller.Asset.video_resolutions_count(&1) <= 1))
      |> Enum.map(& &1.id)

    maybe_log(incomplete_assets, "Re-transcoding #{incomplete_assets} video assets", not dryrun)
    maybe_log(incomplete_assets, "Skipping re-transcoding #{incomplete_assets} video assets", dryrun)

    unless dryrun do
      Enum.reduce(incomplete_assets, 1, fn id, acc ->
        maybe_log(id, "Re-transcoding video asset #{acc}/#{length(incomplete_assets)}", true)
        _ = Controller.Asset.sync_analyze_transcode(id)
        acc + 1
      end)
    end
  end

  @doc """
  This function will look for empty `raw_metadata` to determine if an asset needs analyzing.
  Then it will look at the mimetype to determine if an asset needs transcoding.
  It will also look for a valid static file to determine if an asset needs transcoding.
  """
  def regenerate_all do
    assets =
      Asset
      |> Repo.all()

    mime_valid = fn path, media_type ->
      case AssetFile.Helpers.mime_type(path) do
        {:ok, mime} ->
          mime == media_type

        {:error, reason} ->
          _ = Logger.error(fn -> "#{reason} for path #{path}" end)
          # we make it true because we cannot transcode if `file` command already fails
          true
      end
    end

    staticfile_valid = fn path -> File.exists?(path) end

    raw_metadata_valid = fn m -> m != %{} end

    {to_analyze, to_transcode} =
      Enum.reduce(assets, {[], []}, fn asset, {analyze, transcode} = acc ->
        %{
          data_filename: data_filename,
          id: id,
          media_type: media_type,
          static_path: static_path,
          raw_metadata: raw_metadata,
          static_filename: static_filename
        } = asset

        path_datafile = Path.join(static_path, data_filename)
        path_staticfile = Path.join(static_path, static_filename)

        cond do
          not mime_valid.(path_datafile, media_type) ->
            {analyze, [id | transcode]}

          not staticfile_valid.(path_staticfile) ->
            {analyze, [id | transcode]}

          not raw_metadata_valid.(raw_metadata) ->
            {[id | analyze], transcode}

          true ->
            acc
        end
      end)

    print_asset_ids = fn asset_ids, headers ->
      output =
        asset_ids
        |> Enum.take(10)
        |> Enum.with_index(1)
        |> Enum.map(fn {id, idx} ->
          "#{idx} | #{id}"
        end)

      log_output = headers ++ output
      _ = log_output |> Enum.join("\n") |> Logger.info()
      :ok
    end

    print_asset_ids.(to_analyze, [
      "Maintenance: #{length(to_analyze)} Assets will be marked for analyzing, showing 10",
      "idx | Asset id",
      "--------------"
    ])

    _ = Logger.info("")

    print_asset_ids.(to_transcode, [
      "Maintenance: #{length(to_transcode)} Assets will be marked for analyzing and transcoding, showing 10",
      "idx | Asset id",
      "--------------"
    ])

    Enum.each(to_analyze, &Controller.Asset.analyze(&1))
    Enum.each(to_transcode, &Controller.Asset.analyze_transcode(&1))
  end

  defp recreate_cmd(%Asset{media_type: media_type} = asset),
    do: recreate_cmd(asset, Controller.Asset.normalized_media_type(media_type))

  defp recreate_cmd(asset, :video),
    do: recreate_from_hls(asset, ["dash_720p_1000k.m3u8", "dash_1080p_2000k.m3u8", "dash_1440p_4000k.m3u8"])

  defp recreate_cmd(asset, :audio), do: recreate_from_hls(asset, [])

  defp recreate_from_hls(%Asset{static_path: static_path} = asset, manifests) do
    [asset.static_filename | manifests]
    |> Enum.reverse()
    |> Enum.reduce_while({:error, :no_manifest_found}, fn manifest, acc ->
      path_manifest = Path.join(static_path, manifest)

      case File.exists?(path_manifest) do
        true ->
          {:halt, cmd_parts_txt(asset, path_manifest)}

        false ->
          {:cont, acc}
      end
    end)
  end

  defp cmd_parts_txt(%Asset{static_path: static_path} = asset, path_manifest) do
    path_parts = Path.join(static_path, "parts.txt")
    params = ["s/dash_/file dash_/; w #{path_parts}", path_manifest]

    case System.cmd("sed", params) do
      {_, 0} ->
        cmd_concat(asset, path_parts)

      {msg, code} ->
        {:error, "Creating parts.txt for #{inspect(asset)} failed: #{inspect(msg)}. #{inspect(code)}"}
    end
  end

  defp cmd_concat(asset, path_parts) do
    %{data_filename: data_filename, static_path: static_path, media_type: media_type} = asset
    path_original = Path.join(static_path, data_filename)

    command =
      ["ffmpeg", "-v", "fatal", "-y", "-f", "concat", "-i", path_parts] ++
        codec(data_filename, Controller.Asset.normalized_media_type(media_type)) ++ [path_original]

    {:ok, command}
  end

  defp codec(_original, :video), do: ["-c", "copy"]

  defp codec(original, :audio) do
    c = fn e -> String.ends_with?(original, e) end

    cond do
      c.("ogg") -> ["-c:a", "libvorbis"]
      c.("mpeg") -> ["-c:a", "libmp3lame"]
      c.("mp3") -> ["-c:a", "libmp3lame"]
      true -> ["-c", "copy"]
    end
  end

  defp maybe_replacing_extension(%{data_filename: data_filename, static_path: static_path} = asset) do
    one_ext = data_filename |> String.split(".") |> Enum.drop(-1)
    duplicate_ext = one_ext ++ [List.last(one_ext)]
    name = Enum.join(duplicate_ext, ".")
    p = Path.join(static_path, name)

    if File.exists?(p) do
      {:moved, asset, name}
    else
      maybe_replacing_jpeg_extension(asset, one_ext)
    end
  end

  defp maybe_replacing_jpeg_extension(%{static_path: static_path} = asset, one_ext) do
    [ext | _] = Enum.reverse(one_ext)

    if ext == "jpg" do
      name = "#{Enum.join(one_ext, ".")}.jpeg"
      p = Path.join(static_path, name)

      if File.exists?(p) do
        {:moved, asset, name}
      else
        maybe_removing_original(asset)
      end
    else
      maybe_removing_original(asset)
    end
  end

  defp maybe_removing_original(%{data_filename: data_filename, static_path: static_path} = asset) do
    name = data_filename |> String.split("original_", trim: true) |> Enum.join("original_")
    p = Path.join(static_path, name)

    if File.exists?(p) do
      {:moved, asset, name}
    else
      {:noop, asset}
    end
  end

  defp update_data_filename(%{id: id}, path) do
    cs = %{data_filename: path}

    case Controller.Asset.update(id, cs, false, false) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error(fn -> "Failed updating asset #{id}: #{inspect(reason)}" end)
    end
  end

  defp files_same_size?(asset) do
    %{static_path: static_path, data_filename: data_filename, static_filename: static_filename} = asset
    path_transcoded = Path.join(static_path, static_filename)
    path_original = Path.join(static_path, data_filename)

    size_from_stat = fn path ->
      case File.stat(path) do
        {:ok, %{size: size}} ->
          size

        {:error, reason} ->
          _ = Logger.error(fn -> "Error during File.stat on #{inspect(path)}: #{inspect(reason)}" end)
          0
      end
    end

    size_transcoded = size_from_stat.(path_transcoded)
    size_original = size_from_stat.(path_original)
    size_transcoded == size_original
  end

  defp determine_commands do
    all_originals =
      Asset
      |> where([a], ilike(a.media_type, "video/%") or ilike(a.media_type, "audio/%"))
      |> Repo.all()

    all_originals_count = length(all_originals)

    wrong_originals =
      all_originals
      |> Enum.with_index(1)
      |> Enum.filter(fn {a, idx} ->
        _ =
          if rem(idx, 100) == 0 do
            Logger.info(fn ->
              "Maintenance: Determine transcoding commands, wrong originals #{idx} of #{all_originals_count}"
            end)
          end

        files_same_size?(a)
      end)
      |> Enum.map(fn {a, _} -> a end)

    wrong_originals_count = length(wrong_originals)

    commands =
      wrong_originals
      |> Enum.with_index(1)
      |> Enum.map(fn {a, idx} ->
        _ =
          if rem(idx, 100) == 0 do
            Logger.info(fn -> "Maintenance: Determine transcoding commands #{idx} of #{wrong_originals_count}" end)
          end

        {a, recreate_cmd(a)}
      end)

    manual_commands =
      commands
      |> Enum.filter(fn
        {_, {:ok, _}} -> true
        _ -> false
      end)

    errors =
      commands
      |> Enum.filter(fn
        {_, {:error, _}} -> true
        _ -> false
      end)

    {errors, manual_commands}
  end

  defp maybe_log(data, _msg, false), do: data

  defp maybe_log(data, msg, true) do
    _ = Logger.info(fn -> "#{msg}: #{inspect(data)}" end)
    data
  end
end

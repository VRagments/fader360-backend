defmodule Darth.Controller.Asset do
  @moduledoc false

  @png_media_types ~w(image/png application/png application/x-png)s
  @jpeg_media_types ~w(image/jpeg image/jpg image/jpe_ image/pjpeg image/vnd.swiftview-jpeg)s
  @bitmap_media_types ~w(image/bmp image/x-bmp image/x-bitmap image/x-xbitmap image/x-win-bitmap
                         image/x-windows-bmp image/ms-bmp image/x-ms-bmp application/bmp application/x-bmp
                         application/x-win-bitmap)s
  @svg_media_types ~w(image/svg image/svg+xml)s

  use Darth.Controller, include_crud: true
  alias Darth.MvApiClient
  alias Darth.Controller.AssetLease
  alias Darth.Controller
  alias Darth.Model.Asset, as: AssetStruct
  alias Darth.Model.AssetLease, as: AssetLeaseStruct

  def model_mod(), do: Darth.Model.Asset
  def default_query_sort_by(), do: "updated_at"

  def default_select_fields() do
    ~w(
      attributes
      data_filename
      id
      mv_asset_key
      mv_asset_deeplink_key
      mv_node
      preview_image
      inserted_at
      media_type
      name
      raw_metadata
      static_filename
      static_path
      static_url
      status
      updated_at
    )a
  end

  def new(params) do
    asset = %Asset{
      attributes: %{},
      raw_metadata: %{},
      status: "created"
    }

    Asset.changeset(asset, params)
  end

  def create(params) do
    params |> new() |> Repo.insert()
  end

  def init(asset, params, is_mv_asset \\ false) do
    new_params = %{
      "data_filename" => filename(asset, "original"),
      "static_path" => base_path(asset),
      "status" => "initialized"
    }

    input_file = "#{new_params["static_path"]}/#{new_params["data_filename"]}"

    with {:ok, _} <- write_data_file(new_params["static_path"], input_file, params["data_path"]),
         delete_temp_downloaded_file(params["data_path"], is_mv_asset),
         {:ok, updated_asset} = ok <- update(asset, new_params, false, true),
         :ok <- broadcast("assets", {:asset_analyze_transcode, updated_asset.id}) do
      ok
    else
      err ->
        {:error, "Creating new asset failed: #{inspect(err)}"}
    end
  end

  def update(id, params, publish \\ true, allow_empty_update \\ false)
  def update(_, params, _, false) when map_size(params) == 0, do: {:error, :no_changes}

  def update(nil, _, _, _), do: {:error, :not_found}

  def update(%Asset{} = asset, params, publish, allow_empty_update) do
    cset = Asset.changeset(asset, params)

    if allow_empty_update or cset.changes != %{} do
      case Repo.update(cset) do
        {:ok, updated_asset} = ok ->
          if publish, do: :ok = broadcast("assets", {:asset_updated, updated_asset})
          ok

        err ->
          err
      end
    else
      {:error, :no_changes}
    end
  end

  def update(id, params, publish, allow_empty_update) do
    asset = Repo.get(Asset, id)
    update(asset, params, publish, allow_empty_update)
  end

  def delete(%Asset{} = a) do
    a |> Asset.delete_changeset() |> Repo.delete() |> delete_repo()
  end

  def delete(nil), do: {:error, :not_found}

  def delete(id) do
    Asset |> Repo.get(id) |> delete
  end

  def update_status(id, status), do: update(id, %{status: status}, true)

  @doc """
  Changes the current license of an asset. Existing leases will be disabled, and a new lease created.
  """
  def change_license(%Asset{} = asset, new_license) do
    leases = Controller.AssetLease.current_leases(asset)

    if new_license != "owner" and Enum.any?(leases, &(to_string(&1.license) == new_license)) do
      {:error, :license_already_active}
    else
      leases
      |> Enum.filter(&(&1.license != :owner))
      |> Enum.each(&Controller.AssetLease.disable/1)

      if new_license != "owner" do
        Controller.AssetLease.create(asset, new_license)
      else
        {:ok, Enum.find(leases, leases, &(&1.license == :owner))}
      end
    end
  end

  @doc """
  Check if data_filename and static_path point to valid locations.
  """
  def check_required_paths(%{data_filename: data_filename, static_path: static_path}) do
    if File.exists?(static_path) do
      data_path = Path.join(static_path, data_filename)

      if File.exists?(data_path) do
        :ok
      else
        {:error, :data_filename_not_found}
      end
    else
      {:error, :static_path_not_found}
    end
  end

  @doc """
  Make sure that static_path and data_filename are set correctly on an asset.
  This is the base for any further analyzing, transcoding and other attribute paths.
  """
  def fix_datafile(asset) do
    case check_required_paths(asset) do
      :ok ->
        maybe_move_datafile(asset)

      err ->
        err
    end
  end

  def original_file(asset), do: filename(asset, "original")

  def base_path(asset) do
    path = Application.get_env(:darth, :asset_static_base_path)
    app_path = Application.app_dir(:darth, path)
    Path.join(app_path, asset.id)
  end

  # URL Schema: BASE_URL/ASSET_ID/NAME.SUFFIX
  # e.g. http://localhost:4000/media/4324/cool_video.mkv
  def generate_paths(asset) do
    paths = %{
      "data_filename" => original_file(asset),
      "static_filename" => filename(asset),
      "static_path" => base_path(asset),
      "static_url" => static_asset_url(asset)
    }

    image_paths =
      case normalized_media_type(asset.media_type) do
        :video ->
          %{
            "preview_image" => preview_asset_url(asset),
            "squared_image" => squared_asset_url(asset),
            "thumbnail_image" => thumbnail_asset_url(asset)
          }

        :image ->
          %{
            "lowres_image" => lowres_asset_url(asset),
            "midres_image" => midres_asset_url(asset),
            "preview_image" => preview_asset_url(asset),
            "squared_image" => squared_asset_url(asset),
            "thumbnail_image" => thumbnail_asset_url(asset)
          }

        _ ->
          %{}
      end

    Map.merge(paths, image_paths)
  end

  @doc """
    Analyze asset `id` after fixing all internal paths/attributes asynchronously.
    Returns {:ok, asset} after successfully scheduling analyzing.
  """
  def analyze(id), do: regenerate(id, :asset_analyze)

  @doc """
    Analyze asset `id` after fixing all internal paths/attributes synchronously.
    Returns {:ok, asset} after successfully analyzing.
  """
  def sync_analyze(id), do: regenerate(id, :asset_analyze, true)

  @doc """
    Analyze and transcode asset `id` after fixing all internal paths/attributes asynchronously.
    Returns {:ok, asset} after successfully scheduling analyzing and transcoding.
  """
  def analyze_transcode(id), do: regenerate(id, :asset_analyze_transcode)

  @doc """
    Analyze and transcode asset `id` after fixing all internal paths/attributes synchronously.
    Returns {:ok, asset} after successfully analyzing and transcoding.
  """
  def sync_analyze_transcode(id), do: regenerate(id, :asset_analyze_transcode, true)

  def lowres_asset_url(asset), do: asset_url(asset, "lowres")
  def midres_asset_url(asset), do: asset_url(asset, "midres")
  def preview_asset_url(asset), do: asset_url(asset, "preview")
  def squared_asset_url(asset), do: asset_url(asset, "squared")
  def static_asset_url(asset), do: asset_url(asset)
  def thumbnail_asset_url(asset), do: asset_url(asset, "thumb")

  def lowres_image_path(asset), do: image_path(asset, "lowres")
  def midres_image_path(asset), do: image_path(asset, "midres")
  def original_image_path(asset), do: image_path(asset, "original")
  def preview_image_path(asset), do: image_path(asset, "preview")
  def squared_image_path(asset), do: image_path(asset, "squared")
  def static_image_path(asset), do: image_path(asset)
  def thumbnail_image_path(asset), do: image_path(asset, "thumb")

  def known_types() do
    Asset
    |> select([a], a.media_type)
    |> distinct(true)
    |> Repo.all()
  end

  def normalized_name(%{name: name}) do
    name
    |> Zarex.sanitize()
    |> String.replace(~r/[\`\<\>\'\{\}\[\]\(\)[:space:]]/u, "_")
    |> String.downcase()
  end

  def normalized_media_type("video/" <> _s), do: :video
  def normalized_media_type("audio/" <> _s), do: :audio
  def normalized_media_type(media_type) when media_type in @png_media_types, do: :image
  def normalized_media_type(media_type) when media_type in @jpeg_media_types, do: :image
  def normalized_media_type(media_type) when media_type in @bitmap_media_types, do: :image
  def normalized_media_type(media_type) when media_type in @svg_media_types, do: :image
  def normalized_media_type("image/" <> _s), do: :image
  def normalized_media_type(_), do: nil

  def svg?(asset), do: asset.media_type in @svg_media_types

  @doc """
  Returns the number of transcoded resolutions for a given video asset. Returns `nil` for non-video assets.
  """
  def video_resolutions_count(%Asset{static_path: static_path, static_filename: static_filename, media_type: mt}) do
    case normalized_media_type(mt) do
      :video ->
        path_staticfile = Path.join(static_path, static_filename)

        with {:ok, file} <- File.read(path_staticfile) do
          file
          |> String.split("\n")
          |> Enum.filter(&(not String.starts_with?(&1, "#") && String.ends_with?(&1, ".m3u8")))
          |> Enum.uniq()
          |> length()
        end

      _ ->
        nil
    end
  end

  def get_asset_with_mv_asset_key(mv_asset_key) do
    Repo.get_by(Asset, mv_asset_key: mv_asset_key)
  end

  def create_current_asset_path(asset_filename) do
    default_asset_path = Application.app_dir(:darth, "tmp")

    case File.mkdir_p(default_asset_path) do
      :ok ->
        path = Path.join([default_asset_path, asset_filename])
        {:ok, path}

      {:error, _} ->
        {:error, "Unable to create the asset path"}
    end
  end

  def create_preview_asset_path(asset_filename, asset_previewlinkkey) do
    download_path = Application.get_env(:darth, :mv_asset_preview_download_path)
    app_path = Application.app_dir(:darth, download_path)
    default_preview_asset_folder = Path.join(app_path, asset_previewlinkkey)

    case File.mkdir_p(default_preview_asset_folder) do
      :ok ->
        path = Path.join([default_preview_asset_folder, asset_filename])
        {:ok, path}

      {:error, _} ->
        {:error, "Unable to create the asset path"}
    end
  end

  def create_file(mv_asset_filename) do
    with {:ok, path} <- create_current_asset_path(mv_asset_filename) do
      File.open(path, [:write, :binary])
    end
  end

  def create_preview_file(mv_asset_filename, asset_previewlinkkey) do
    with {:ok, path} <- create_preview_asset_path(mv_asset_filename, asset_previewlinkkey) do
      File.open(path, [:write, :binary])
    end
  end

  def add_asset_to_database(params, user) do
    mv_asset_key = Map.get(params, "mv_asset_key")

    case get_asset_with_mv_asset_key(mv_asset_key) do
      nil ->
        with {:ok, asset_struct} <- create(params), do: create_asset_lease(user, params, asset_struct)

      asset_struct = %Asset{} ->
        ensure_user_asset_lease(asset_struct, user, params)
    end
  end

  def is_audio_asset?(media_type), do: normalized_media_type(media_type) == :audio

  def is_video_asset?(media_type), do: normalized_media_type(media_type) == :video

  def is_image_asset?(media_type), do: normalized_media_type(media_type) == :image

  def is_asset_status_ready?(asset_status), do: asset_status == "ready"

  def is_asset_download_failed?(asset_status, asset_mv_node),
    do: is_mv_asset?(asset_mv_node) and (asset_status == "created" or asset_status == "download_failed")

  def is_mv_asset?(asset_mv_node), do: asset_mv_node != nil

  def get_sorted_asset_lease_list(asset_leases_map) do
    asset_leases_map
    |> Map.values()
    |> Enum.sort_by(& &1.inserted_at)
  end

  def asset_already_added?(mv_asset_key, user_id) do
    with %AssetStruct{} = asset_struct <- get_asset_with_mv_asset_key(mv_asset_key),
         asset_lease = %AssetLeaseStruct{} <- AssetLease.read_by_user_and_asset(user_id, asset_struct.id) do
      asset_lease.asset.status == "ready"
    else
      _ -> false
    end
  end

  def is_audio_or_video_asset?(media_type),
    do: is_audio_asset?(media_type) or is_video_asset?(media_type)

  def ensure_user_asset_lease(asset_struct, user, params) do
    with {:ok, asset_lease} <- check_asset_lease(asset_struct, user),
         true <- AssetLease.has_user?(asset_lease, user) do
      {:ok, asset_lease}
    else
      nil ->
        create_asset_lease(user, params, asset_struct)

      false ->
        create_asset_lease(user, params, asset_struct)

      {:error, reason} ->
        Logger.error("Unable to add user to the current asset lease: #{inspect(reason)}")
        {:error, reason}
    end
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp filename(%Asset{media_type: media_type} = asset, prefix \\ "") do
    name = normalized_name(asset)
    data_suffix = if prefix == "original", do: "", else: ".#{media_type_to_file_suffix(media_type, prefix)}"
    prefix = media_type_to_file_prefix(media_type, prefix)
    ~s(#{prefix}#{name}#{data_suffix})
  end

  @preview_image_prefixes ~w(preview squared thumb)s
  defp media_type_to_file_suffix("video/" <> _, prefix) when prefix in @preview_image_prefixes, do: "jpg"
  defp media_type_to_file_suffix("video/" <> _, _), do: "m3u8"
  defp media_type_to_file_suffix("audio/" <> _, _), do: "m3u8"
  defp media_type_to_file_suffix(media_type, _) when media_type in @png_media_types, do: "png"
  defp media_type_to_file_suffix(media_type, _) when media_type in @jpeg_media_types, do: "jpg"
  defp media_type_to_file_suffix(media_type, _) when media_type in @bitmap_media_types, do: "bmp"
  defp media_type_to_file_suffix(media_type, _) when media_type in @svg_media_types, do: "svg"

  defp media_type_to_file_prefix(_, prefix) when byte_size(prefix) == 0, do: ""
  defp media_type_to_file_prefix(_, prefix), do: ~s(#{prefix}_)

  defp write_data_file(_path, _file, data_path) when data_path in ["", nil], do: {:error, :data_missing}

  defp write_data_file(path, file, data_path) do
    with :ok <- File.mkdir_p(path), do: File.copy(data_path, file)
  end

  defp image_path(asset, prefix \\ "") do
    path = base_path(asset)
    name = filename(asset, prefix)
    ~s(#{path}/#{name})
  end

  defp asset_url(asset, prefix \\ "") do
    base_url = DarthWeb.Endpoint.url()
    name = filename(asset, prefix)
    "#{base_url}/media/#{asset.id}/#{name}"
  end

  defp delete_repo({:ok, asset}) do
    broadcast("assets", {:asset_deleted, asset})
  end

  defp delete_repo(err), do: err

  defp maybe_move_datafile(%{data_filename: data_filename, id: id, static_path: static_path} = asset) do
    data_path = Path.join(static_path, data_filename)
    target_file = original_file(asset)

    if target_file == data_filename do
      {:ok, asset}
    else
      targe_path = Path.join(static_path, target_file)

      case File.rename(data_path, targe_path) do
        :ok ->
          update(id, %{data_filename: target_file}, false, false)

        err ->
          err
      end
    end
  end

  defp regenerate(data, target, sync \\ false)
  defp regenerate({:error, _} = err, _, _), do: err
  defp regenerate({:ok, asset}, t, sync), do: regenerate(asset, t, sync)

  defp regenerate(%Asset{id: id} = asset, target, false) do
    with {:ok, _} = ok <- fix_datafile(asset),
         :ok <- broadcast("assets", {target, id}) do
      ok
    else
      {:error, reason} = err ->
        _ = Logger.error("Regenerating(target: #{target}) asset #{id} failed: #{inspect(reason)}")
        err
    end
  end

  defp regenerate(%Asset{id: id} = asset, target, true) do
    done_fun = fn asset_id, repeat_fun ->
      case target do
        :asset_analyze ->
          receive do
            {:asset_analyzing_done, _asset_id} ->
              :ok

            {:asset_analyzing_failed, _asset_id, _err} ->
              :ok

            _ ->
              repeat_fun.(asset_id, repeat_fun)
          end

        :asset_analyze_transcode ->
          receive do
            {:asset_transcoding_done, _asset_id} ->
              :ok

            {:asset_transcoding_failed, _asset_id, _err} ->
              :ok

            _ ->
              repeat_fun.(asset_id, repeat_fun)
          end
      end
    end

    with {:ok, _} = ok <- fix_datafile(asset),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- broadcast("assets", {target, id}) do
      done_fun.(id, done_fun)
      :ok = Phoenix.PubSub.unsubscribe(Darth.PubSub, "assets")
      ok
    else
      {:error, reason} = err ->
        _ = Logger.error("Regenerating(target: #{target}) asset #{id} failed: #{inspect(reason)}")
        err
    end
  end

  defp regenerate(asset_id, t, sync), do: regenerate(read(asset_id), t, sync)

  def build_asset_params(params, mv_asset_file_path \\ nil) do
    %{
      "name" => params.mv_asset_filename,
      "mv_node" => params.mv_node,
      "media_type" => params.media_type,
      "mv_asset_key" => params.mv_asset_key,
      "mv_asset_deeplink_key" => params.mv_asset_deeplink_key,
      "mv_token" => params.mv_token,
      "data_path" => mv_asset_file_path
    }
  end

  defp delete_temp_downloaded_file(current_asset_path, is_mv_asset) do
    with true <- is_mv_asset,
         :ok <- File.rm(current_asset_path) do
      Logger.info("Deleted the temporarily downloaded file")
    else
      false ->
        Logger.info("Skipped the file deletion as it is not a downloaded MV Asset")

      {:error, reason} ->
        Logger.warning("Unable to delete the temporarily downloaded file: #{inspect(reason)}")
    end
  end

  defp create_asset_lease(user, params, asset_struct) do
    license = decide_asset_lease_license(params)

    case create_asset_lease_for_mv_asset(asset_struct, user, license) do
      {:ok, asset_lease} ->
        {:ok, asset_lease}

      {:error, reason} ->
        Logger.error("Unable to add MediaVerse asset to the databse: #{reason}")
        {:error, reason}
    end
  end

  defp create_asset_lease_for_mv_asset(asset_struct, user, license) do
    case AssetLease.create_for_user_with_license(asset_struct, user, license) do
      {:ok, asset_lease} ->
        asset_lease = Repo.preload(asset_lease, :asset)
        {:ok, asset_lease}

      {:error, reason} ->
        Logger.error("Error while creating the asset lease with license creator for mv_asset: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp decide_asset_lease_license(params) do
    mv_node = Map.get(params, "mv_node")
    mv_token = Map.get(params, "mv_token")
    mv_asset_key = Map.get(params, "mv_asset_key")

    case MvApiClient.asset_created_by_current_user?(mv_node, mv_token, mv_asset_key) do
      true -> :creator
      false -> :owner
    end
  end

  defp check_asset_lease(asset_struct, user) do
    case AssetLease.read_by_user_and_asset(user.id, asset_struct.id) do
      asset_lease = %AssetLeaseStruct{} -> {:ok, asset_lease}
      _ -> nil
    end
  end
end

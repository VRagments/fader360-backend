defmodule Darth.Controller.AssetSubtitle do
  @moduledoc false
  @srt_media_types ~w(application/x-subrip application/octet-stream text/plain)s

  use Darth.Controller, include_crud: true

  alias Darth.Model.AssetSubtitle, as: AssetSubtitleStruct

  def model_mod, do: Darth.Model.AssetSubtitle

  def default_query_sort_by, do: "updated_at"

  def default_select_fields do
    ~w(
      asset_id
      mv_asset_subtitle_key
      static_path
      static_url
      id
      inserted_at
      language
      name
      updated_at
      version
    )a
  end

  def default_preload_assocs do
    ~w(
      asset
    )a
  end

  def new(params) do
    asset_id = params["asset_id"]
    filename = params["name"]

    params =
      if is_nil(params["version"]) or params["version"] == "" do
        Map.put(params, "version", "0")
      else
        params
      end
      |> Map.put("static_url", create_static_url(asset_id, filename))

    AssetSubtitleStruct.changeset(%AssetSubtitleStruct{}, params)
  end

  def create(params) do
    with {:ok, as} <-
           params
           |> new()
           |> Repo.insert(
             on_conflict: {:replace_all_except, [:id, :inserted_at]},
             conflict_target: [:asset_id, :mv_asset_subtitle_key]
           ),
         :ok <- broadcast("asset_subtitles", {:asset_subtitle_created, as}) do
      read(as.id)
    end
  end

  def update({:error, _} = err, _), do: err
  def update({:ok, asset_subtitle}, params), do: update(asset_subtitle, params)

  def update(%AssetSubtitleStruct{} = asset_subtitle, params) do
    cset = AssetSubtitleStruct.changeset(asset_subtitle, params)

    case Repo.update(cset) do
      {:ok, asset_subtitle} = ok ->
        broadcast("asset_subtitles", {:asset_subtitle_updated, asset_subtitle})
        ok

      err ->
        err
    end
  end

  def update(id, params), do: id |> read() |> update(params)

  def delete(%AssetSubtitleStruct{} = as),
    do: as |> AssetSubtitleStruct.delete_changeset() |> Repo.delete() |> delete_repo()

  def delete(nil), do: {:error, :not_found}
  def delete(id), do: AssetSubtitleStruct |> Repo.get(id) |> delete

  def write_data_file(source, _file, _dest) when source in ["", nil], do: {:error, :data_missing}

  def write_data_file(source, file, dest) do
    with :ok <- File.mkdir_p(dest), do: File.copy(source, file)
  end

  def asset_subtitle_base_path(asset_id) do
    path = Application.get_env(:darth, :asset_static_base_path)
    app_path = Application.app_dir(:darth, path)
    Path.join([app_path, asset_id, "subtitles"])
  end

  def query_by_asset(asset_id) do
    AssetSubtitleStruct
    |> where([as], as.asset_id == ^asset_id)
    |> Repo.all()
  end

  def query_by_asset_mv_key_and_version(asset_id, mv_asset_subtitle_key, version) do
    query =
      AssetSubtitleStruct
      |> where(
        [as],
        as.asset_id == ^asset_id and as.mv_asset_subtitle_key == ^mv_asset_subtitle_key and as.version == ^version
      )

    Repo.one(query)
  end

  def normalized_media_type(media_type) when media_type in @srt_media_types, do: :srt
  def normalized_media_type(_), do: nil

  defp create_static_url(asset_id, filename) do
    base_url = DarthWeb.Endpoint.url()
    Path.join([base_url, "media", asset_id, "subtitles", filename])
  end

  defp delete_repo({:ok, asset_subtitle}) do
    broadcast("asset_subtitles", {:asset_subtitle_deleted, asset_subtitle})
  end

  defp delete_repo(err), do: err
end

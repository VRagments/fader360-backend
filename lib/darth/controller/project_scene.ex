defmodule Darth.Controller.ProjectScene do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.Model.ProjectScene, as: ProjectSceneStruct

  def model_mod, do: Darth.Model.ProjectScene

  def default_query_sort_by, do: "updated_at"

  def default_select_fields do
    ~w(
      duration
      id
      inserted_at
      name
      primary_asset_lease_id
      project_id
      updated_at
      user_id
      navigatable
    )a
  end

  def default_preload_assocs do
    ~w(
      primary_asset
      primary_asset_lease
      project
      user
    )a
  end

  def new(params) do
    params =
      params
      |> Map.put("duration", Application.fetch_env!(:darth, :default_project_scene_duration))

    ProjectSceneStruct.changeset(%ProjectSceneStruct{}, params)
  end

  def create(params) do
    with {:ok, ps} <- params |> new() |> Repo.insert(),
         :ok <- broadcast("project_scenes", {:project_scene_created, ps}) do
      read(ps.id)
    end
  end

  def update({:error, _} = err, _), do: err
  def update({:ok, project_scene}, params), do: update(project_scene, params)

  def update(%ProjectSceneStruct{} = project_scene, params) do
    cset = ProjectSceneStruct.changeset(project_scene, params)

    case Repo.update(cset) do
      {:ok, project_scene} = ok ->
        broadcast("projects", {:project_scene_updated, project_scene})
        ok

      err ->
        err
    end
  end

  def update(id, params), do: id |> read() |> update(params)

  def delete(%ProjectSceneStruct{} = a),
    do: a |> ProjectSceneStruct.delete_changeset() |> Repo.delete() |> delete_repo()

  def delete(nil), do: {:error, :not_found}
  def delete(id), do: ProjectSceneStruct |> Repo.get(id) |> delete

  def has_primary_asset_lease?(project_scene), do: not is_nil(project_scene.primary_asset_lease_id)

  def unassign_primary_asset_lease(project_scene, asset_lease) do
    with true <- project_scene.primary_asset_lease_id == asset_lease.id,
         {:ok, project_scene} <- update(project_scene, %{primary_asset_lease_id: nil}) do
      {:ok, project_scene}
    else
      false ->
        {:ok, project_scene}

      _ ->
        {:error, "unable to update the primary asset"}
    end
  end

  def get_sorted_project_scenes_list(project_scenes_map) do
    project_scenes_map
    |> Map.values()
    |> Enum.sort_by(& &1.inserted_at)
  end

  defp delete_repo({:ok, project_scene}) do
    broadcast("project_scenes", {:project_scene_deleted, project_scene})
  end

  defp delete_repo(err), do: err
end

defmodule Darth.Controller.ProjectScene do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.Model.ProjectScene, as: ProjectSceneStruct
  alias Darth.Controller.Project

  def model_mod, do: Darth.Model.ProjectScene

  def default_query_sort_by, do: "updated_at"

  def default_select_fields do
    ~w(
      data
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
      if is_nil(params["data"]) or params["data"] == "" do
        Map.put(params, "data", %{})
      else
        params
      end

    params =
      if is_nil(params["duration"]) or params["duration"] == "" do
        Map.put(params, "duration", Application.fetch_env!(:darth, :default_project_scene_duration))
      else
        params
      end

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

  def dublicate(old_project, new_project) do
    old_project_data = old_project.data
    old_project_scene_list_in_order = Map.get(old_project_data, "sceneOrder")

    with new_project_scene_list_in_order <-
           Enum.map(old_project_scene_list_in_order, fn old_project_scene_id ->
             create_and_copy_scene(old_project_scene_id, new_project.id)
           end),
         false <-
           Enum.any?(new_project_scene_list_in_order, fn new_project_scene -> new_project_scene == :error end),
         new_project_data = Map.put(old_project_data, "sceneOrder", new_project_scene_list_in_order),
         {:ok, project} <- Project.update(new_project, %{data: new_project_data}) do
      {:ok, project}
    else
      _ ->
        {:error, "Error while coping the project scenes"}
    end
  end

  defp create_and_copy_scene(original_scene_id, new_project_id) do
    with {:ok, original_scene} <- read(original_scene_id, [:primary_asset_lease]),
         params = %{
           "name" => original_scene.name,
           "duration" => original_scene.duration,
           "navigatable" => original_scene.navigatable,
           "project_id" => new_project_id,
           "data" => original_scene.data,
           "user_id" => original_scene.user_id
         },
         {:ok, new_scene} <- create(params),
         {:ok, _new_scene} <- copy_primary_asset_lease(new_scene, original_scene.primary_asset_lease) do
      new_scene.id
    else
      err ->
        Logger.error("Error while dublicating the scene: #{inspect(err)}")
        :error
    end
  end

  defp copy_primary_asset_lease(scene, nil), do: {:ok, scene}

  defp copy_primary_asset_lease(scene, lease) do
    case update(scene, %{primary_asset_lease_id: lease.id}) do
      {:ok, scene} ->
        {:ok, scene}

      err ->
        Logger.error("Error while dublicating the scene: #{inspect(err)}")
        {:ok, scene}
    end
  end

  defp delete_repo({:ok, project_scene}) do
    broadcast("project_scenes", {:project_scene_deleted, project_scene})
  end

  defp delete_repo(err), do: err
end

defmodule DarthWeb.ApiProjectSceneView do
  use DarthWeb, :view

  alias Darth.Repo
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct

  def render("index.json", %{entries: entries, total_entries: total}) do
    %{
      total: total,
      objects: render_many(entries, __MODULE__, "project_scene.json")
    }
  end

  def render("show.json", %{object: project_scene}) do
    render_one(project_scene, __MODULE__, "project_scene.json")
  end

  def render("project_scene.json", %{api_project_scene: ps}) do
    %{
      created_at: render_date(ps.inserted_at),
      id: ps.id,
      name: ps.name,
      duration: ps.duration,
      preview_image: render_primary_asset(ps, :preview_image),
      primary_asset_lease_id: ps.primary_asset_lease_id,
      project_id: ps.project_id,
      thumbnail_image: render_primary_asset(ps, :thumbnail_image),
      updated_at: render_date(ps.updated_at),
      navigatable: ps.navigatable
    }
  end

  def render_primary_asset(%ProjectSceneStruct{primary_asset_lease_id: nil}, _image), do: nil

  def render_primary_asset(project_scene, image) do
    project_scene
    |> Repo.preload([:primary_asset, :primary_asset_lease])
    |> Map.get(:primary_asset)
    |> Map.get(image)
  end
end

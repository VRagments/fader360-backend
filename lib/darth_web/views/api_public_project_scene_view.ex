defmodule DarthWeb.ApiPublicProjectSceneView do
  use DarthWeb, :view

  alias DarthWeb.ApiProjectSceneView

  def render("index.json", %{entries: entries, total_entries: total}) do
    %{
      total: total,
      objects: render_many(entries, __MODULE__, "project_scene.json")
    }
  end

  def render("show.json", %{object: project_scene}) do
    render_one(project_scene, __MODULE__, "project_scene.json")
  end

  def render("project_scene.json", %{api_public_project_scene: ps}) do
    %{
      created_at: render_date(ps.inserted_at),
      id: ps.id,
      name: ps.name,
      duration: ps.duration,
      data: ps.data,
      preview_image: ApiProjectSceneView.render_primary_asset(ps, :preview_image),
      primary_asset_lease_id: ps.primary_asset_lease_id,
      project_id: ps.project_id,
      thumbnail_image: ApiProjectSceneView.render_primary_asset(ps, :thumbnail_image),
      updated_at: render_date(ps.updated_at),
      navigatable: ps.navigatable
    }
  end
end

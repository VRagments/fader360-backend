defmodule DarthWeb.ApiProjectView do
  use DarthWeb, :view

  alias Darth.Repo
  alias Darth.Model.Project, as: ProjectStruct

  def render("index.json", %{entries: entries, total_entries: total}) do
    %{
      total: total,
      objects: render_many(entries, __MODULE__, "partial-project.json")
    }
  end

  def render("show.json", %{object: project}) do
    render_one(project, __MODULE__, "project.json")
  end

  def render("project.json", %{api_project: p}) do
    %{
      author: p.author,
      created_at: render_date(p.inserted_at),
      custom_colorscheme: p.custom_colorscheme,
      custom_font: p.custom_font,
      custom_icon_audio: p.custom_icon_audio,
      custom_icon_image: p.custom_icon_image,
      custom_icon_video: p.custom_icon_video,
      custom_logo: p.custom_logo,
      custom_player_settings: p.custom_player_settings,
      data: p.data,
      id: p.id,
      last_updated_at: render_date(p.updated_at),
      name: p.name,
      preview_image: render_primary_asset(p, :preview_image),
      primary_asset_lease_id: p.primary_asset_lease_id,
      squared_image: render_primary_asset(p, :squared_image),
      thumbnail_image: render_primary_asset(p, :thumbnail_image),
      updated_at: render_date(p.updated_at),
      user_display_name: p.user.display_name,
      visibility: p.visibility
    }
  end

  def render("partial-project.json", %{api_project: p}) do
    %{
      author: p.author,
      id: p.id,
      name: p.name,
      preview_image: render_primary_asset(p, :preview_image),
      visibility: p.visibility,
      squared_image: render_primary_asset(p, :squared_image),
      thumbnail_image: render_primary_asset(p, :thumbnail_image),
      updated_at: render_date(p.updated_at),
      last_updated_at: render_date(p.updated_at)
    }
  end

  def render_primary_asset(%ProjectStruct{primary_asset_lease_id: nil}, _image), do: nil

  def render_primary_asset(project, image) do
    project
    |> Repo.preload([:primary_asset, :primary_asset_lease])
    |> Map.get(:primary_asset)
    |> Map.get(image)
  end
end

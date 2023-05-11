defmodule DarthWeb.ApiPublicProjectAssetSubtitleView do
  use DarthWeb, :view

  def render("index.json", %{entries: entries, total_entries: total}) do
    %{
      total: total,
      objects: render_many(entries, __MODULE__, "asset_subtitle.json")
    }
  end

  def render("show.json", %{object: asset_subtitle}) do
    render_one(asset_subtitle, __MODULE__, "asset_subtitle.json")
  end

  def render("asset_subtitle.json", %{api_public_project_asset_subtitle: as}) do
    %{
      created_at: render_date(as.inserted_at),
      id: as.id,
      name: as.name,
      static_path: as.static_path,
      static_url: as.static_url,
      language: as.language,
      version: as.version,
      asset_id: as.asset_id,
      updated_at: render_date(as.updated_at)
    }
  end
end

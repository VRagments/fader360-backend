defmodule Darth.Repo.Migrations.RemoveStaticPathFieldFromAssetsAndAssetSubtitlesTable do
  use Ecto.Migration

  def change do
    alter table("assets") do
      remove :static_path
    end

    alter table("asset_subtitles") do
      remove :static_path
    end
  end
end

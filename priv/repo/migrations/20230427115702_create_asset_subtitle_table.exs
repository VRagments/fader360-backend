defmodule Darth.Repo.Migrations.CreateAssetSubtitleTable do
  use Ecto.Migration

  def change do
    create table("asset_subtitles") do
      add(:name, :text, null: false)
      add(:static_path, :string, null: false)
      add(:static_url, :string, null: false)
      add(:language, :string)
      add(:version, :string, null: false)
      add(:mv_asset_subtitle_key, :string)
      add(:asset_id, references(:assets, on_delete: :delete_all), null: false)
      timestamps()
    end

    create(unique_index(:asset_subtitles, [:asset_id, :mv_asset_subtitle_key]))
  end
end

defmodule Darth.Repo.Migrations.CreateAssetSubtitleTable do
  use Ecto.Migration

  def change do
    create table("asset_subtitles") do
      add(:name, :text, null: false)
      add(:static_path, :string, null: false)
      add(:static_url, :string, null: false)
      add(:language, :string)
      add(:version, :string, null: false)
      add(:asset_id, references(:assets, on_delete: :delete_all), null: false)
      timestamps()
    end
  end
end

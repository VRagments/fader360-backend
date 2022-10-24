defmodule Darth.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table("assets") do
      add(:name, :string, null: false)
      add(:media_type, :string, null: false)
      add(:status, :string, null: false)
      add(:mv_asset_key, :text)
      add(:mv_asset_deeplink_key, :text)
      add(:mv_node, :string)

      add(:data_filename, :text)
      add(:static_filename, :text)
      add(:static_path, :text)
      add(:static_url, :text)
      add(:lowres_image, :text)
      add(:midres_image, :text)
      add(:preview_image, :text)
      add(:squared_image, :text)
      add(:thumbnail_image, :text)

      add(:attributes, :map)
      add(:raw_metadata, :map)

      timestamps()
    end

    create(index("assets", [:mv_asset_key], unique: true))
    create(index("assets", [:mv_asset_deeplink_key], unique: true))
  end
end

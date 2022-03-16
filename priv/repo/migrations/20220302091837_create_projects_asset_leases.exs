defmodule Darth.Repo.Migrations.CreateProjectsAssetLeases do
  use Ecto.Migration

  def change do
    create table("projects_asset_leases", primary_key: false) do
      add(:project_id, references(:projects, on_delete: :delete_all), null: false)
      add(:asset_lease_id, references(:asset_leases, on_delete: :delete_all), null: false)
    end

    create(index("projects_asset_leases", [:project_id, :asset_lease_id], unique: true))
  end
end

defmodule Darth.Repo.Migrations.CreateProjectScenes do
  use Ecto.Migration

  def change do
    create table("project_scenes") do
      add(:name, :text, null: false)
      add(:duration, :text, null: false)
      add(:navigatable, :boolean, null: false)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:project_id, references(:projects, on_delete: :delete_all), null: false)
      add(:primary_asset_lease_id, references(:asset_leases, on_delete: :nilify_all))
      timestamps()
    end
  end
end

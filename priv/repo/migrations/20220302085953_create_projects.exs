defmodule Darth.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create_query =
      "CREATE TYPE project_visibility AS ENUM ('private', 'link_share', 'discoverable')"

    drop_query = "DROP TYPE project_visibility"
    execute(create_query, drop_query)

    create table("projects") do
      add(:name, :text, null: false)
      add(:visibility, :project_visibility, null: false)

      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      add(:author, :string)
      add(:data, :map)

      add(:primary_asset_lease_id, references(:asset_leases, on_delete: :nilify_all))

      timestamps()
    end
  end
end

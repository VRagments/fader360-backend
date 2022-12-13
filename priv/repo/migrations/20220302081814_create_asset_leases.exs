defmodule Darth.Repo.Migrations.CreateAssetLeases do
  use Ecto.Migration

  def change do
    create_query = "CREATE TYPE asset_lease_license AS ENUM ('owner', 'link_share', 'public')"
    drop_query = "DROP TYPE asset_lease_license"
    execute(create_query, drop_query)

    create table("asset_leases") do
      add(:license, :asset_lease_license, null: false)
      add(:valid_since, :utc_datetime, null: false)

      add(:asset_id, references(:assets), null: false)

      add(:valid_until, :utc_datetime)

      timestamps()
    end

    create(index("asset_leases", [:license]))
  end
end

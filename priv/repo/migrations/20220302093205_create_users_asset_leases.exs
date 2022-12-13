defmodule Darth.Repo.Migrations.CreateUsersAssetLeases do
  use Ecto.Migration

  def change do
    create table("users_asset_leases", primary_key: false) do
      add(:user_id, references(:users), null: false)
      add(:asset_lease_id, references(:asset_leases), null: false)
    end

    create(index("users_asset_leases", [:user_id, :asset_lease_id], unique: true))
  end
end

defmodule Darth.Repo.Migrations.ChangeAssetLeaseLiceseEnumType do
  use Ecto.Migration

  def change do
    alter_query = "ALTER TYPE asset_lease_license RENAME VALUE 'link_share' TO 'creator';"
    execute(alter_query)
  end
end

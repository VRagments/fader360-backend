defmodule Darth.Repo.Migrations.UpdateUsersUniqueConstraint do
  use Ecto.Migration

  def change do
    drop(index(:users, [:email]))
    create(unique_index(:users, [:email, :mv_node]))
  end
end

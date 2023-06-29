defmodule Darth.Repo.Migrations.AddPublishedFieldToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add(:published?, :boolean)
    end
  end
end

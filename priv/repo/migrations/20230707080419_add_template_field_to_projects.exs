defmodule Darth.Repo.Migrations.AddTemplateFieldToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add(:template?, :boolean)
    end
  end
end

defmodule Darth.Repo.Migrations.AddDataFieldToProjectScenes do
  use Ecto.Migration

  def change do
    alter table("project_scenes") do
      add :data, :map
    end
  end
end

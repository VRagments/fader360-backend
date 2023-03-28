defmodule Darth.Repo.Migrations.AddMvProjectIdToProjectsTable do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :mv_project_id, :text
    end
  end
end

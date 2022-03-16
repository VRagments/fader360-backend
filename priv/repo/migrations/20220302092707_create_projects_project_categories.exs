defmodule Darth.Repo.Migrations.CreateProjectsProjectCategories do
  use Ecto.Migration

  def change do
    create table("projects_project_categories", primary_key: false) do
      add(:project_id, references(:projects, on_delete: :delete_all))
      add(:project_category_id, references(:project_categories, on_delete: :delete_all))
    end
  end
end

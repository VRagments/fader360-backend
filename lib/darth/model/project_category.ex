defmodule Darth.Model.ProjectCategory do
  @moduledoc false

  use Darth.Model

  alias Darth.Model.Project

  schema "project_categories" do
    field(:name, :string)

    many_to_many(:projects, Project,
      join_through: "projects_project_categories",
      on_replace: :delete
      # on_delete: :delete_all (set through migration)
    )

    timestamps()
  end

  def search_attributes do
    ~w(
       id
       name
     )
  end

  @allowed_fields ~w(name)a

  @required_fields ~w(name)a

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end

  def default_category_name(), do: "featured"
  def all_categories_name(), do: "__all__"

  #
  # INTERNAL FUNCTIONS
  #
end

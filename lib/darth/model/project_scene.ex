defmodule Darth.Model.ProjectScene do
  use Darth.Model
  alias Darth.Model.{AssetLease, User, Project}

  schema "project_scenes" do
    field(:name, :string)
    field(:duration, :string)
    field(:navigatable, :boolean)

    belongs_to(:user, User)
    belongs_to(:project, Project)
    belongs_to(:primary_asset_lease, AssetLease)

    has_one(:primary_asset, through: [:primary_asset_lease, :asset], on_delete: :nilify_all)

    timestamps()
  end

  def search_attributes do
    ~w(
       id
       name
     )
  end

  @allowed_fields ~w(duration name user_id project_id primary_asset_lease_id navigatable)a

  @required_fields ~w(duration name user_id project_id navigatable)a

  def delete_changeset(model), do: model |> common_changeset(%{}) |> Map.put(:action, :delete)

  def changeset(model, params \\ %{}), do: common_changeset(model, params)

  defp common_changeset(model, params) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:user)
    |> assoc_constraint(:primary_asset_lease)
  end
end

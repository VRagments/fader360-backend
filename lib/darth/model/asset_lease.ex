defmodule Darth.Model.AssetLease do
  @moduledoc false

  use Darth.Model

  alias Darth.Model.{Asset, Project, User}

  schema "asset_leases" do
    field(:license, Ecto.Enum, values: [:owner, :link_share, :public])
    field(:valid_since, :utc_datetime)
    # for read operations only the existence of a lease makes it valid
    # for assigning leases the validity is tied to the timeframe of a lease
    field(:valid_until, :utc_datetime)

    belongs_to(:asset, Asset)

    has_many(:project_primaries, Project,
      foreign_key: :primary_asset_lease_id,
      on_delete: :nilify_all
    )

    many_to_many(:projects, Project, join_through: "projects_asset_leases", on_replace: :delete)
    many_to_many(:users, User, join_through: "users_asset_leases", on_replace: :delete)

    timestamps()

    field(:owner_username, :string, virtual: true)
  end

  def search_attributes do
    ~w()
  end

  @allowed_fields ~w(license valid_since valid_until asset_id)a

  @required_fields ~w(license valid_since asset_id)a

  def changeset(model, params \\ %{}), do: common_changeset(model, params)

  def delete_changeset(model), do: model |> common_changeset(%{}) |> Map.put(:action, :delete)

  def data_changed?(_model) do
    # TODO: make proper change check
    False
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp common_changeset(model, params) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:asset)
    |> no_assoc_constraint(:project_primaries)
  end
end

defmodule Darth.Model.Project do
  @moduledoc false

  use Darth.Model

  alias Darth.Model.{AssetLease, ProjectCategory, User}

  schema "projects" do
    field(:name, :string)
    field(:author, :string)
    field(:data, :map)
    field(:visibility, Ecto.Enum, values: [:private, :link_share, :discoverable])

    belongs_to(:user, User)
    belongs_to(:primary_asset_lease, AssetLease)

    has_one(:primary_asset, through: [:primary_asset_lease, :asset], on_delete: :nilify_all)

    many_to_many(:asset_leases, AssetLease,
      join_through: "projects_asset_leases",
      on_delete: :delete_all
    )

    many_to_many(:project_categories, ProjectCategory,
      join_through: "projects_project_categories",
      on_replace: :delete
      # on_delete: :delete_all (set through migration)
    )

    has_many(:assets, through: [:asset_leases, :asset])

    timestamps()

    # These are custom values from the connected user model, kept here for easier access. If unset, the client
    # should use some default values.
    field(:custom_colorscheme, :map, virtual: true)
    field(:custom_font, :string, virtual: true)
    field(:custom_icon_audio, :string, virtual: true)
    field(:custom_icon_image, :string, virtual: true)
    field(:custom_icon_video, :string, virtual: true)
    field(:custom_logo, :string, virtual: true)
    field(:custom_player_settings, :map, virtual: true)
  end

  def search_attributes do
    ~w(
       id
       name
     )
  end

  def virtual_attributes do
    ~w(
      custom_colorscheme
      custom_font
      custom_icon_audio
      custom_icon_image
      custom_icon_video
      custom_logo
      custom_player_settings
    )
  end

  @allowed_fields ~w(author name visibility user_id data primary_asset_lease_id)a

  @required_fields ~w(name visibility user_id)a

  def delete_changeset(model), do: model |> common_changeset(%{}) |> Map.put(:action, :delete)

  def changeset(model, params \\ %{}), do: common_changeset(model, params)

  #
  # INTERNAL FUNCTIONS
  #

  defp common_changeset(model, params) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:user)
    |> assoc_constraint(:primary_asset_lease)
  end
end

defmodule Darth.Model.AssetSubtitle do
  use Darth.Model
  alias Darth.Model.Asset

  schema "asset_subtitles" do
    field(:name, :string)
    field(:static_path, :string)
    field(:static_url, :string)
    field(:language, Ecto.Enum, values: [:-, :EN, :ES, :DE, :PL, :SL, :IT])
    field(:version, :string)
    field(:mv_asset_subtitle_key, :string)

    belongs_to(:asset, Asset)

    timestamps()
  end

  def search_attributes do
    ~w(
       id
       name
     )
  end

  @allowed_fields ~w(asset_id static_path static_url language name version mv_asset_subtitle_key)a

  @required_fields ~w(asset_id static_path static_url name version)a

  def delete_changeset(model), do: model |> common_changeset(%{}) |> Map.put(:action, :delete)

  def changeset(model, params \\ %{}), do: common_changeset(model, params)

  defp common_changeset(model, params) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:asset)
  end
end

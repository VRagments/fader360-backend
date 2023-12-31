defmodule Darth.Model.Asset do
  @moduledoc false

  use Darth.Model

  alias Darth.Model.{AssetLease, AssetSubtitle}

  schema "assets" do
    field(:data_filename, :string)
    field(:media_type, :string)
    field(:name, :string)
    field(:static_filename, :string)
    field(:static_url, :string)
    field(:mv_asset_key, :string)
    field(:mv_asset_deeplink_key, :string)
    field(:mv_node, :string)

    # TODO convert to enum, ~w(created initialized analyzing_started analyzing_failed
    # analyzing_finished transcoding_started transcoding_failed ready)
    field(:status, :string)

    field(:lowres_image, :string)
    field(:midres_image, :string)
    field(:preview_image, :string)
    field(:squared_image, :string)
    field(:thumbnail_image, :string)

    # Asset metadata, derived from raw_metadata
    # duration - seconds - float
    # file_size - byte - int
    # height - pixel - int
    # width - pixel - int
    field(:attributes, :map)
    # this field will contain raw metadata, that we determined through different means
    # analysis - ffprobe/convert determination of media data - json string
    # plug - browser uploaded filename and media type - json string
    # stat - file stats on original file - json string
    field(:raw_metadata, :map)
    has_many(:asset_leases, AssetLease)

    has_many(:projects, through: [:asset_leases, :projects])
    has_many(:users, through: [:asset_leases, :users])
    has_many(:asset_subtitles, AssetSubtitle)

    timestamps()
  end

  def search_attributes do
    [
      "media_type",
      "name",
      {"owner_username", Darth.Model.User}
    ]
  end

  def virtual_attributes do
    ~w(
       owner_username
     )a
  end

  @allowed_fields ~w(name media_type status attributes static_url lowres_image midres_image
                     data_filename static_filename preview_image raw_metadata squared_image
                     thumbnail_image mv_asset_key mv_asset_deeplink_key mv_node)a

  @required_fields ~w(name media_type status)a

  @valid_media_type ~r/^(audio|image|video|application\/png|application\/x-png|application\/bmp|application\/x-bmp|\
    application\/x-win-bitmap|model)\//

  def delete_changeset(model),
    do:
      model
      |> changeset()
      |> foreign_key_constraint(:asset_leases,
        name: :asset_leases_asset_id_fkey,
        message: "Asset cannot be deleted as it is being used by other users through asset lease"
      )
      |> Map.put(:action, :delete)

  def changeset(model, params \\ %{}), do: common_changeset(model, params)

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
    |> validate_format(:media_type, @valid_media_type)
  end
end

defmodule DarthWeb.ApiAssetSubtitleController do
  use DarthWeb, :controller
  import Ecto.Query
  alias DarthWeb.QueryParameters
  alias Darth.Controller.AssetSubtitle
  alias Darth.Controller.AssetLease
  alias Darth.Model.AssetSubtitle, as: AssetSubtitleStruct

  def swagger_definitions do
    %{
      AssetSubtitle:
        swagger_schema do
          title("AssetSubtitle")
          description("An asset subtitle")

          properties do
            id(:string, "Asset Subtitle ID")
            name(:string, "Subtitle filename")
            static_path(:string, "Path to the subtitle file in the static folder")
            static_url(:string, "Url to the subtitle file in the static folder")
            language(:string, "Subtitle language")
            version(:string, "Subtitle file version")
            asset_id(:string, "Asset id to which the subtitle file in related")
            inserted_at(:string, "Created at this time (Date)")
            updated_at(:string, "updated at this time (Date)")
          end

          example(%{
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            name: "subtitle_EN.srt",
            static_path: "/Users/Documents/app/lib/app/priv/static/subtitle_EN.srt",
            static_url: "http://localhost:45020/subtitle_EN.srt",
            language: "EN",
            version: "0",
            asset_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            inserted_at: "2015-11-10T02:15:25Z",
            updated_at: "2015-11-10T02:15:25Z"
          })
        end,
      AssetSubtitles:
        swagger_schema do
          title("AssetSubtitles")
          description("A list of asset subtitles")

          properties do
            objects(Schema.array(:AssetSubtitle), "An asset subtitle")
            total(:integer, "The total count of all asset subtitles")
          end

          example(%{
            total: 11,
            entries: [
              %{
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "subtitle_EN.srt",
                static_path: "/Users/Documents/app/lib/app/priv/static/subtitle_EN.srt",
                static_url: "http://localhost:45020/subtitle_EN.srt",
                language: "EN",
                version: "0",
                asset_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                inserted_at: "2015-11-10T02:15:25Z",
                updated_at: "2015-11-10T02:15:25Z"
              },
              %{
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "subtitle_EN.srt",
                static_path: "/Users/Documents/app/lib/app/priv/static/subtitle_EN.srt",
                static_url: "http://localhost:45020/subtitle_EN.srt",
                language: "EN",
                version: "0",
                asset_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                inserted_at: "2015-11-10T02:15:25Z",
                updated_at: "2015-11-10T02:15:25Z"
              }
            ]
          })
        end
    }
  end

  swagger_path(:index) do
    get("/api/assets/{id}/asset_subtitles")
    summary("List Asset subtitles")

    description(~s(Returns list of asset subtitles based on input parameters.
                   Only returns asset subtitles associated with the asset.))

    produces("application/json")
    security([%{Bearer: []}])

    QueryParameters.list_query()

    parameters do
      id(:path, :string, "Asset ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:AssetSubtitles))
    response(404, "Not Found")
  end

  def index(conn, %{"api_asset_id" => asset_id} = params) do
    current_user = conn.assigns.current_api_user
    user_asset_leases = AssetLease.query_by_user(current_user.id, params)
    asset_lease = Enum.find(user_asset_leases.entries, fn asset_lease -> asset_lease.asset_id == asset_id end)

    unless is_nil(asset_lease) do
      query = AssetSubtitleStruct |> where([as], as.asset_id == ^asset_lease.asset.id)
      asset_subtitles = AssetSubtitle.query(params, query)
      render(conn, "index.json", asset_subtitles)
    else
      {:error, :not_found}
    end
  end

  swagger_path(:show) do
    get("/api/assets/{api_asset_id}/asset_subtitles/{id}")
    summary("Details of Asset subtitle")

    description(~s(Returns details of a given asset subtitle.
                   Only allowed for Asset subtitle for the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      api_asset_id(:path, :string, "Asset ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )

      id(:path, :string, "Asset Subtitle ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:AssetSubtitle))
    response(404, "Not Found")
  end

  def show(conn, %{"api_asset_id" => asset_id, "id" => asset_subtitle_id} = params) do
    current_user = conn.assigns.current_api_user
    user_asset_leases = AssetLease.query_by_user(current_user.id, params)
    asset_lease = Enum.find(user_asset_leases.entries, fn asset_lease -> asset_lease.asset_id == asset_id end)

    with true <- not is_nil(asset_lease),
         {:ok, asset_subtitle} <- AssetSubtitle.read(asset_subtitle_id),
         true <- asset_subtitle.asset_id == asset_lease.asset_id do
      conn
      |> put_status(:ok)
      |> render("show.json", object: asset_subtitle)
    else
      _ ->
        {:error, :not_found}
    end
  end
end

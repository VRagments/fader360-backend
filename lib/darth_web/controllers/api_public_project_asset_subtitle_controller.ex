defmodule DarthWeb.ApiPublicProjectAssetSubtitleController do
  use DarthWeb, :controller
  import Ecto.Query
  alias DarthWeb.QueryParameters
  alias Darth.Controller.{AssetSubtitle, AssetLease, Project}
  alias Darth.Model.AssetSubtitle, as: AssetSubtitleStruct

  swagger_path(:index) do
    get("/api/public/projects/{project_id}/assets/{asset_lease_id}/asset_subtitles")
    summary("List Asset subtitles")

    description(~s(Returns list of asset subtitles based on input parameters.
                   Only returns asset subtitles associated with the asset.))

    produces("application/json")

    QueryParameters.list_query()

    parameters do
      project_id(:path, :string, "Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )

      asset_lease_id(:path, :string, "Asset Lease ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:AssetSubtitles))
    response(404, "Not Found")
  end

  def index(
        conn,
        %{"api_public_project_asset_id" => asset_lease_id, "api_public_project_id" => project_id} = params
      ) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         {:ok, project} <- Project.read(project_id),
         true <- project.visibility != :private do
      query = AssetSubtitleStruct |> where([as], as.asset_id == ^asset_lease.asset.id)
      asset_subtitles = AssetSubtitle.query(params, query)
      render(conn, "index.json", asset_subtitles)
    else
      _ -> {:error, :not_found}
    end
  end

  swagger_path(:show) do
    get("/api/public/projects/{project_id}/assets/{asset_lease_id}/asset_subtitles/{asset_subtitle_id}")
    summary("Details of Asset subtitle")

    description(~s(Returns details of a given asset subtitle.
                   Only allowed for Asset subtitle for the authenticated user.))

    produces("application/json")

    parameters do
      project_id(:path, :string, "Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )

      asset_lease_id(:path, :string, "Asset Lease ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )

      asset_subtitle_id(:path, :string, "Asset Subtitle ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:AssetSubtitle))
    response(404, "Not Found")
  end

  def show(conn, %{
        "api_public_project_asset_id" => asset_lease_id,
        "api_public_project_id" => project_id,
        "id" => asset_subtitle_id
      }) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         {:ok, project} <- Project.read(project_id),
         true <- project.visibility != :private,
         {:ok, asset_subtitle} <- AssetSubtitle.read(asset_subtitle_id),
         true <- asset_subtitle.asset_id == asset_lease.asset.id do
      conn
      |> put_status(:ok)
      |> render("show.json", object: asset_subtitle)
    else
      _ -> {:error, :not_found}
    end
  end
end

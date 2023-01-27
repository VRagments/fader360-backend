defmodule DarthWeb.ApiPublicProjectAssetController do
  use DarthWeb, :controller
  alias DarthWeb.QueryParameters
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Project

  swagger_path(:index) do
    get("/api/public/projects/{id}/assets")
    summary("List Public Assets associated with a Project")

    description(~s(Returns list of assets associated with a given project based on input parameters.
         Only allowed for public projects. Only covers asset leases which are associated with that project.))

    produces("application/json")

    QueryParameters.list_query()

    parameters do
      id(
        :path,
        :string,
        "Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:PublicAssets))
    response(404, "Not Found, if the project visibility prohibits the call")
  end

  def index(conn, %{"api_public_project_id" => project_id} = params) do
    fun = fn _user ->
      assigns = AssetLease.query_by_public_project(project_id, params)
      render(conn, "index.json", assigns)
    end

    ensure_project_allowed(project_id, fun)
  end

  swagger_path(:show) do
    get("/api/public/projects/{project_id}/assets/{id}")
    summary("Show Public Asset associated with a Project")

    description(~s(Returns details of a given asset which is associated with a given project.
                   Only allowed for public projects. Only allowed for asset leases associated with that project.))

    produces("application/json")

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")

      project_id(
        :path,
        :string,
        "Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:PublicAsset))
    response(404, "Not Found, if the project or asset visibility prohibit the call")
  end

  def show(conn, %{"api_public_project_id" => project_id, "id" => id}) do
    fun = fn ->
      case AssetLease.read_by_project(project_id, id) do
        nil ->
          {:error, :not_found}

        asset_lease ->
          conn
          |> put_status(:ok)
          |> render("show.json", object: asset_lease)
      end
    end

    ensure_project_allowed(project_id, fun)
  end

  defp ensure_project_allowed(project_id, fun) do
    with {:ok, project} <- Project.read(project_id) do
      if project.visibility != :private do
        fun.()
      else
        {:error, :not_found}
      end
    end
  end
end

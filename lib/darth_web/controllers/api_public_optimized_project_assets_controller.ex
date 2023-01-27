defmodule DarthWeb.ApiPublicOptimizedProjectAssetsController do
  use DarthWeb, :controller
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Project

  swagger_path(:index) do
    get("/api/public/optimized/projects/{id}/assets")
    summary("List all Public Assets associated with a Project")

    description(~s(Returns list of all assets associated with a given project.
         Only allowed for public projects. Only covers asset leases which are associated with that project.))

    produces("application/json")

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:PublicAssets))
    response(404, "Not Found, if the project visibility prohibits the call")
  end

  def index(conn, %{"api_public_optimized_project_id" => project_id}) do
    with {:ok, project} <- Project.read(project_id) do
      if project.visibility == :private do
        {:error, :not_found}
      else
        assigns = AssetLease.optimized_by_public_project(project_id)
        render(conn, "index.json", assigns)
      end
    end
  end
end

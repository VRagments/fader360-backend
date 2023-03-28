defmodule DarthWeb.ApiProjectAssetController do
  use DarthWeb, :controller
  alias DarthWeb.QueryParameters
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Project
  alias Darth.Controller.Asset

  swagger_path(:index) do
    get("/api/projects/{id}/assets")
    summary("List Assets associated with a Project")

    description(~s(Returns list of assets associated with a given project based on input parameters.
                   Only allowed for public projects and projects owned by the authenticated user.
                   Only allowed for public asset leases and asset leases owned by the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])

    QueryParameters.list_query()

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Assets))
    response(404, "Not Found, if the project visibility prohibits the call")
  end

  def index(conn, %{"api_project_id" => project_id} = params) do
    fun = fn is_owner, _project ->
      assigns =
        if is_owner do
          AssetLease.query_by_accessible_project(project_id, params, false)
        else
          AssetLease.query_by_accessible_project(project_id, params)
        end

      render(conn, "index.json", assigns)
    end

    ensure_project_allowed(conn, project_id, fun, false)
  end

  swagger_path(:show) do
    get("/api/projects/{api_project_id}/assets/{id}")
    summary("Show Asset associated with a Project")

    description(~s(Returns details of a given asset which is associated with a given project.
                   Only allowed for public projects and projects owned by the authenticated user.
                   Only allowed for public asset leases and asset leases owned by the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")

      api_project_id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Asset))
    response(404, "Not Found, if the project or asset visibility prohibit the call")
  end

  def show(conn, %{"api_project_id" => project_id, "id" => id}) do
    fun = fn _is_owner, _project ->
      case AssetLease.read_by_project(project_id, id) do
        nil ->
          {:error, :not_found}

        lease ->
          conn
          |> put_status(:ok)
          |> render("show.json", object: lease)
      end
    end

    ensure_project_allowed(conn, project_id, fun)
  end

  swagger_path(:create) do
    post("/api/projects/{project_id}/assets")
    summary("Create Asset and assign it to the given Project")

    description(~s(Creates new asset and corresponding asset lease with type owner.
                   Assigns the asset lease to the given project.
                   Returns details of the created asset.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      api_project_id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    QueryParameters.asset_create_or_update()

    response(201, "Created", Schema.ref(:Asset))
    response(422, "Error")
  end

  def create(conn, %{"api_project_id" => project_id} = params) do
    asset_params = read_media_file_data(params)

    fun = fn user, _is_owner, project ->
      with {:ok, asset} <- Asset.create(asset_params),
           {:ok, asset} <- Asset.init(asset, asset_params),
           {:ok, lease} <- AssetLease.create_for_user_project(asset, user, project) do
        conn
        |> put_status(:created)
        |> render("show.json", object: lease)
      end
    end

    ensure_project_allowed(conn, project_id, fun)
  end

  defp ensure_project_allowed(conn, project_id, fun, only_as_owner \\ true) do
    user = conn.assigns.current_api_user

    with {:ok, project} <- Project.read(project_id) do
      if (not only_as_owner and project.visibility != :private) or project.user_id == user.id do
        fun.(project.user_id == user.id, project)
      else
        {:error, :not_found}
      end
    end
  end
end

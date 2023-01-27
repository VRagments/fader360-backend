defmodule DarthWeb.ApiPublicProjectController do
  use DarthWeb, :controller
  import Ecto.Query
  alias DarthWeb.QueryParameters
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.Project

  swagger_path(:index) do
    get("/api/public/projects")
    summary("List Public Projects")

    description(~s(Returns list of projects based on input parameters.
                   Only returns public projects.))

    produces("application/json")

    QueryParameters.list_query()

    response(200, "OK", Schema.ref(:Projects))
  end

  def index(conn, params) do
    query = ProjectStruct |> where([p], p.visibility == "discoverable")
    assigns = Project.query(params, query)
    render(conn, "index.json", assigns)
  end

  swagger_path(:show) do
    get("/api/public/projects/{id}")
    summary("Show Project")

    description(~s(Returns details of a given project.
                   Only allowed for public projects.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Project))
    response(404, "Not Found, if the project visibility prohibits the call")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, project} <- Project.read(id) do
      user = conn.assigns.current_api_user

      # We show the project if the user is the owner or the project is not private
      if project.visibility != :private or (not is_nil(user) and project.user_id == user.id) do
        conn
        |> put_status(:ok)
        |> render("show.json", object: project)
      else
        {:error, :not_found}
      end
    end
  end

  swagger_path(:recommendations) do
    get("/api/public/projects/{api_public_project_id}/recommendations")
    summary("List Public Projects associated with this Project")

    description(~s(Returns list of projects based on input parameters.
                   Only returns other public projects that are created by the same user.))

    produces("application/json")

    QueryParameters.list_query()

    parameters do
      api_public_project_id(
        :path,
        :string,
        "Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:Projects))
    response(404, "Not Found")
  end

  def recommendations(conn, %{"api_public_project_id" => id} = params) do
    with {:ok, project} <- Project.read(id) do
      assigns = Project.query_recommendations(project, params)
      render(conn, "index.json", assigns)
    end
  end
end

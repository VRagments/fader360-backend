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
    query = ProjectStruct |> where([p], p.visibility == :discoverable)
    assigns = Project.query(params, query)
    render(conn, "index.json", assigns)
  end

  swagger_path(:show) do
    get("/api/public/projects/{id}")
    summary("Show Project")

    description(~s(Returns details of a given project.
                   Only allowed for public projects.))

    produces("application/json")

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Project))
    response(404, "Not Found, if the project visibility prohibits the call")
  end

  def show(conn, %{"id" => id}) do
    # We show the project if the user is the owner or the project is not private
    with {:ok, project} <- Project.read(id),
         true <- project.visibility != :private do
      conn
      |> put_status(:ok)
      |> render("show.json", object: project)
    else
      _ -> {:error, :not_found}
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

  swagger_path(:verify_hash) do
    get("/api/public/projects/{api_public_project_id}/verify_project_hash/{api_public_project_result_hash}")

    summary("Verification to see if the project result is altered")

    description(~s(Returns true if the project result is not altered or false if it is altered))

    produces("application/json")

    parameters do
      api_public_project_id(
        :path,
        :string,
        "Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )

      api_public_project_result_hash(
        :path,
        :string,
        "Project result hash",
        required: true,
        example: "LFM525WSWRT3W24O7OW63QGA4SGF2COIIFXUCYH2EE3Y7GLKTMMQ===="
      )
    end

    response(204, "Success - No Content")
    response(422, "Result altered")
  end

  def verify_hash(conn, %{
        "api_public_project_id" => api_public_project_id,
        "project_hash" => api_public_project_hash
      }) do
    uri_decoded_hash = URI.decode(api_public_project_hash)

    with {:ok, built_project_hash} <-
           Project.build_project_hash_to_publish(api_public_project_id),
         true <- built_project_hash == uri_decoded_hash do
      send_resp(conn, :no_content, "")
    else
      _ -> {:error, :forbidden}
    end
  end
end

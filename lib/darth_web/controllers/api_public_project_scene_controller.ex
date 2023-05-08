defmodule DarthWeb.ApiPublicProjectSceneController do
  use DarthWeb, :controller
  import Ecto.Query
  alias DarthWeb.QueryParameters
  alias Darth.Controller.Project
  alias Darth.Controller.ProjectScene
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct

  swagger_path(:index) do
    get("/api/public/projects/{id}/project_scenes")
    summary("List Public Project Scenes")

    description(~s(Returns list of Public project scenes based on input parameters.
                   Only returns project scenes associated with the given public project.))

    produces("application/json")

    QueryParameters.list_query()

    parameters do
      id(:path, :string, "Public Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:ProjectScenes))
    response(404, "Not Found")
  end

  def index(conn, %{"api_public_project_id" => project_id} = params) do
    query = ProjectSceneStruct |> where([ps], ps.project_id == ^project_id)

    with {:ok, project} <- Project.read(project_id),
         true <- project.visibility != :private do
      assigns = ProjectScene.query(params, query)
      render(conn, "index.json", assigns)
    else
      _ -> {:error, :not_found}
    end
  end

  swagger_path(:show) do
    get("/api/public/projects/{api_project_id}/project_scenes/{id}")
    summary("Show Public Project Scene")

    description(~s(Returns details of a given public project scene.))

    produces("application/json")

    parameters do
      api_project_id(:path, :string, "Project ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )

      id(:path, :string, "Project Scene ID",
        required: true,
        example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55"
      )
    end

    response(200, "OK", Schema.ref(:ProjectScene))
    response(404, "Not Found, if the project scene does not belong to the current user")
  end

  def show(conn, %{"api_public_project_id" => project_id, "id" => project_scene_id}) do
    with {:ok, project} <- Project.read(project_id),
         true <- project.visibility != :private,
         {:ok, project_scene} <- ProjectScene.read(project_scene_id),
         true <- project_scene.project_id == project_id do
      conn
      |> put_status(:ok)
      |> render("show.json", object: project_scene)
    else
      _ ->
        {:error, :not_found}
    end
  end
end

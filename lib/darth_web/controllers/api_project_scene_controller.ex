defmodule DarthWeb.ApiProjectSceneController do
  use DarthWeb, :controller
  require Logger
  import Ecto.Query
  alias Darth.Repo
  alias Darth.Controller.ProjectScene
  alias Darth.Controller.Project
  alias Darth.Controller.Asset
  alias DarthWeb.QueryParameters
  alias DarthWeb.ApiProjectSceneView
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct

  def swagger_definitions do
    %{
      ProjectSceneBody:
        swagger_schema do
          title("ProjectScene")
          description("A project scene")

          properties do
            name(:string, "User-provided project scene name")
            navigatable(:boolean, "User selected option to allow jumping to scene")
            primary_asset_lease_id(:string, "Asset lease id used for project scene background image")
          end

          example(%{
            name: "scene one",
            primary_asset_lease_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            navigatable: true
          })
        end,
      ProjectScene:
        swagger_schema do
          title("ProjectScene")
          description("A project scene")

          properties do
            created_at(:string, "Creation datetime")
            duration(:string, "Duration of the project scene")
            id(:string, "Project Scene id")
            name(:string, "User-provided project scene name")
            navigatable(:boolean, "User selected option to allow jumping to scene")
            project_id(:string, "Project id under which scene is created")
            preview_image(:string, "URL for the project scene's preview image")
            primary_asset_lease_id(:string, "Asset lease id used for project scene background image")
            thumbnail_image(:string, "URL for the project's thumbnail image")
            updated_at(:string, "Last update datetime")
          end

          example(%{
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            name: "scene one",
            duration: "60",
            preview_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
            primary_asset_lease_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            project_id: "gd414aa6-1h91-4a22-9ab4-275cc6ddf7b7",
            thumbnail_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg",
            navigatable: true,
            updated_at: "2015-11-10T02:15:25Z",
            created_at: "2015-11-10T02:15:25Z"
          })
        end,
      ProjectScenes:
        swagger_schema do
          title("ProjectScenes")
          description("A list of project scenes")

          properties do
            objects(Schema.array(:ProjectScene), "A project scene")
            total(:integer, "The total count of all project scenes")
          end

          example(%{
            total: 11,
            entries: [
              %{
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "scene one",
                duration: "60",
                preview_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
                primary_asset_lease_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                project_id: "gd414aa6-1h91-4a22-9ab4-275cc6ddf7b7",
                thumbnail_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg",
                navigatable: true,
                updated_at: "2015-11-10T02:15:25Z",
                created_at: "2015-11-10T02:15:25Z"
              },
              %{
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "scene one",
                duration: "60",
                preview_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
                primary_asset_lease_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                project_id: "gd414aa6-1h91-4a22-9ab4-275cc6ddf7b7",
                thumbnail_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg",
                navigatable: true,
                updated_at: "2015-11-10T02:15:25Z",
                created_at: "2015-11-10T02:15:25Z"
              }
            ]
          })
        end
    }
  end

  swagger_path(:index) do
    get("/api/projects/{id}/project_scenes")
    summary("List Project Scenes")

    description(~s(Returns list of project scenes based on input parameters.
                   Only returns project scenes associated with the project.))

    produces("application/json")
    security([%{Bearer: []}])

    QueryParameters.list_query()

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:ProjectScenes))
    response(404, "Not Found")
  end

  def index(conn, %{"api_project_id" => project_id} = params) do
    user = conn.assigns.current_api_user
    query = ProjectSceneStruct |> where([ps], ps.user_id == ^user.id and ps.project_id == ^project_id)
    assigns = ProjectScene.query(params, query)
    render(conn, "index.json", assigns)
  end

  swagger_path(:create) do
    post("/api/projects/{id}/project_scenes")
    summary("Create Project Scene")

    description(~s(Creates new project scene.
                   Returns details of the created project scene.))

    produces("application/json")
    security([%{Bearer: []}])

    QueryParameters.project_scene_create_or_update()

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(201, "Created", Schema.ref(:ProjectScene))
    response(422, "Error")
  end

  def create(conn, %{"api_project_id" => project_id} = params) do
    user = conn.assigns.current_api_user

    params =
      params
      |> Map.put("user_id", user.id)
      |> Map.put("project_id", project_id)

    with {:ok, project_scene} <- ProjectScene.create(params) do
      conn
      |> put_status(:created)
      |> render("show.json", object: project_scene)
    end
  end

  swagger_path(:show) do
    get("/api/projects/{api_project_id}/project_scenes/{id}")
    summary("Show Project Scene")

    description(~s(Returns details of a given project scene.
                   Only allowed for projects scenes owned by the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])

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

  def show(conn, %{"api_project_id" => project_id, "id" => project_scene_id}) do
    user = conn.assigns.current_api_user

    with {:ok, project_scene} <- ProjectScene.read(project_scene_id),
         true <- project_scene.project_id == project_id,
         true <- project_scene.user_id == user.id do
      conn
      |> put_status(:ok)
      |> render("show.json", object: project_scene)
    else
      {:error, _} ->
        {:error, :not_found}

      false ->
        {:error, :not_found}
    end
  end

  swagger_path(:update) do
    put("/api/projects/{api_project_id}/project_scenes/{id}")
    summary("Update Project Scene")
    description("Updates project Scene. Only allowed for project owners.")
    produces("application/json")
    security([%{Bearer: []}])

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

    QueryParameters.project_scene_create_or_update()

    response(200, "OK", Schema.ref(:ProjectScene))
    response(404, "Not Found, if the project visibility prohibits the call")
    response(422, "Error")
  end

  def update(conn, %{"api_project_id" => project_id, "id" => project_scene_id} = params) do
    with {:ok, project} <- Project.read(project_id),
         {:ok, project_scene} <- ProjectScene.read(project_scene_id),
         params =
           params
           |> Map.put("last_updated_at", DateTime.utc_now())
           |> convert_primary_asset_id(project),
         {:ok, _updated_project_scene} <- ProjectScene.update(project_scene, params) do
      {:ok, updated_project_scene} = ProjectScene.read(project_scene.id)
      payload = Phoenix.View.render(ApiProjectSceneView, "show.json", object: updated_project_scene)
      DarthWeb.Endpoint.broadcast!("project_scene:" <> updated_project_scene.id, "project_scene:updated", payload)

      conn
      |> put_status(:ok)
      |> render("show.json", object: updated_project_scene)
    end
  end

  swagger_path(:delete) do
    PhoenixSwagger.Path.delete("/api/projects/{api_project_id}/project_scenes/{id}")
    summary("Delete Project Scene")

    description(~s(If the authenticated user is the project owner:
                   Delete the given scene of given project.))

    produces("application/json")
    security([%{Bearer: []}])

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

    response(204, "Success - No Content")
    response(404, "Not Found")
    response(422, "Error")
  end

  def delete(conn, %{"api_project_id" => project_id, "id" => project_scene_id}) do
    user = conn.assigns.current_api_user

    with {:ok, project_scene} <- ProjectScene.read(project_scene_id),
         true <- project_scene.project_id == project_id,
         true <- project_scene.user_id == user.id,
         :ok <- ProjectScene.delete(project_scene_id) do
      send_resp(conn, :no_content, "")
    else
      {:error, _} ->
        {:error, :not_found}

      false ->
        {:error, :not_found}
    end
  end

  defp convert_primary_asset_id(%{"primary_asset_id" => primary_asset_id} = params, project) do
    %{asset_leases: asset_leases} = Repo.preload(project, :asset_leases)

    lease =
      Enum.find(
        asset_leases,
        &(&1.asset_id == primary_asset_id and Asset.normalized_media_type(&1.asset.media_type) != :audio)
      )

    id = if is_nil(lease), do: "", else: lease.id

    params
    |> Map.delete("primary_asset_id")
    |> Map.put("primary_asset_lease_id", id)
  end

  defp convert_primary_asset_id(params, _project), do: params
end

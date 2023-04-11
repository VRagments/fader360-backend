defmodule DarthWeb.ApiProjectController do
  use DarthWeb, :controller
  require Logger
  import Ecto.Query
  alias Darth.Repo
  alias DarthWeb.ApiProjectView
  alias DarthWeb.QueryParameters
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.Project
  alias Darth.Controller

  def swagger_definitions do
    %{
      ProjectCreateBody:
        swagger_schema do
          title("Project")
          description("User project")

          properties do
            name(:string, "User-provided project name")
            visibility(:string, "Current project visibility")
          end

          example(%{
            name: "my project one",
            visibility: "public"
          })
        end,
      ProjectUpdateBody:
        swagger_schema do
          title("Project")
          description("User project")

          properties do
            name(:string, "User-provided project name")
            data(Schema.ref(:ProjectData), "Custom project data")
            primary_asset_lease_id(:string, "Asset lease id used for project images")
            visibility(:string, "Current project visibility")
          end

          example(%{
            name: "my project one",
            data: %{
              "key_one" => "somedate",
              "key_two" => "someotherdate"
            },
            primary_asset_lease_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            visibility: "public"
          })
        end,
      Project:
        swagger_schema do
          title("Project")
          description("A project")

          properties do
            author(:string, "Creator of the project")
            created_at(:string, "Creation datetime")
            custom_colorscheme(Schema.ref(:ProjectCustomColorscheme), "Custom project colorscheme")
            custom_logo(:string, "Static URL to a logo file")
            custom_font(:string, "Static URL to a font file")
            data(Schema.ref(:ProjectData), "Custom project data")
            id(:string, "Project ID")
            last_updated_at(:string, "Last user update datetime")
            name(:string, "User-provided project name")
            preview_image(:string, "URL for the project's preview image")
            primary_asset_lease_id(:string, "Asset lease id used for project images")
            squared_image(:string, "URL for the project's squared image")
            thumbnail_image(:string, "URL for the project's thumbnail image")
            updated_at(:string, "Last update datetime")
            user_display_name(:string, "display name of story creator")
            visibility(:string, "Current project visibility")
          end

          example(%{
            author: "Mister X",
            custom_colorscheme: %{
              "primary" => "ff22ff",
              "secondary" => "22ff22",
              "font" => "ff22ff"
            },
            custom_logo: "http://localhost/uploads/922d2d05-1f91-4a22-9ca4-275dd6ddf7b7.png",
            custom_font: "http://localhost/uploads/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7.ttf",
            data: %{
              "key_one" => "somedate",
              "key_two" => "someotherdate"
            },
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            name: "my project one",
            preview_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
            primary_asset_lease_id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            squared_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
            thumbnail_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg",
            visibility: "public",
            updated_at: "2015-11-10T02:15:25Z",
            user_display_name: "Marie Curie",
            last_updated_at: "2015-11-10T02:15:25Z",
            created_at: "2015-11-10T02:15:25Z"
          })
        end,
      PartialProject:
        swagger_schema do
          title("PartialProject")
          description("A partial project")

          properties do
            author(:string, "Creator of the project")
            id(:string, "Project ID")
            last_updated_at(:string, "Last user update datetime")
            name(:string, "User-provided project name")
            preview_image(:string, "URL for the project's preview image")
            squared_image(:string, "URL for the project's squared image")
            thumbnail_image(:string, "URL for the project's thumbnail image")
            updated_at(:string, "Last update datetime")
            visibility(:string, "Current project visibility")
          end

          example(%{
            author: "Mister X",
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            name: "my project one",
            preview_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
            squared_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
            thumbnail_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg",
            visibility: "public",
            updated_at: "2015-11-10T02:15:25Z",
            last_updated_at: "2015-11-10T02:15:25Z"
          })
        end,
      Projects:
        swagger_schema do
          title("Projects")
          description("A list of projects")

          properties do
            objects(Schema.array(:PartialProject), "A partial project")
            total(:integer, "The total count of all projects")
          end

          example(%{
            total: 11,
            entries: [
              %{
                author: "Mister X",
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "my project one",
                preview_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
                squared_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
                thumbnail_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg",
                visibility: "public",
                updated_at: "2015-11-10T02:15:25Z",
                last_updated_at: "2015-11-10T02:15:25Z"
              },
              %{
                author: "Mister X",
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "my project one",
                preview_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
                squared_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
                thumbnail_image: "http://localhost/projects/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg",
                visibility: "public",
                updated_at: "2015-11-10T02:15:25Z",
                last_updated_at: "2015-11-10T02:15:25Z"
              }
            ]
          })
        end,
      ProjectData:
        swagger_schema do
          title("ProjectData")
          description("Custom project data")

          properties do
            some_key_one(:string, "some custom key")
            another_key(:string, "another custom key")
          end

          example(%{
            some_key_one: "my data",
            another_key: "other data here"
          })
        end,
      ProjectCustomColorscheme:
        swagger_schema do
          title("ProjectColorscheme")
          description("Custom project colorscheme")

          properties do
            some_key_one(:string, "some custom key")
            another_key(:string, "another custom key")
          end

          example(%{
            primary: "ffff22",
            secondary: "2222ff",
            font: "ffff22"
          })
        end
    }
  end

  swagger_path(:index) do
    get("/api/projects")
    summary("List Projects")

    description(~s(Returns list of projects based on input parameters.
                   Only returns projects owned by the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])

    QueryParameters.list_query()

    response(200, "OK", Schema.ref(:Projects))
  end

  def index(conn, params) do
    user = conn.assigns.current_api_user
    query = ProjectStruct |> where([p], p.user_id == ^user.id)
    assigns = Project.query(params, query)
    render(conn, "index.json", assigns)
  end

  swagger_path(:create) do
    post("/api/projects")
    summary("Create Project")

    description(~s(Creates new project.
                   Returns details of the created project.))

    produces("application/json")
    security([%{Bearer: []}])

    QueryParameters.project_create()

    response(201, "Created", Schema.ref(:Project))
    response(422, "Error")
  end

  def create(conn, params) do
    user = conn.assigns.current_api_user

    params =
      params
      |> Map.put("user_id", user.id)
      |> Map.put("author", user.display_name)

    with {:ok, project} <- Project.create(params) do
      conn
      |> put_status(:created)
      |> render("show.json", object: project)
    end
  end

  swagger_path(:show) do
    get("/api/projects/{id}")
    summary("Show Project")

    description(~s(Returns details of a given project.
                   Only allowed for projects owned by the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Project))
    response(404, "Not Found, if the project visibility prohibits the call")
  end

  def show(conn, %{"id" => id}) do
    fun = fn _user, _is_owner, project ->
      conn
      |> put_status(:ok)
      |> render("show.json", object: project)
    end

    conn.assigns.current_api_user
    |> Controller.ensure_project_access_allowed(id, fun)
  end

  swagger_path(:update) do
    put("/api/projects/{id}")
    summary("Update Project")
    description("Updates project. Only allowed for project owners.")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    QueryParameters.project_update()

    response(200, "OK", Schema.ref(:Project))
    response(404, "Not Found, if the project visibility prohibits the call")
    response(422, "Error")
  end

  def update(conn, %{"id" => id} = params) do
    fun = fn _user, _is_owner, project ->
      params =
        params
        |> convert_primary_asset_id(project)

      with {:ok, _updated_project} <- Project.update(project, params) do
        {:ok, updated_project} = Project.read(project.id)
        payload = Phoenix.View.render(ApiProjectView, "show.json", object: updated_project)
        DarthWeb.Endpoint.broadcast!("project:" <> updated_project.id, "project:updated", payload)

        conn
        |> put_status(:ok)
        |> render("show.json", object: updated_project)
      end
    end

    conn.assigns.current_api_user
    |> Controller.ensure_project_access_allowed(id, fun)
  end

  swagger_path(:delete) do
    PhoenixSwagger.Path.delete("/api/projects/{id}")
    summary("Delete Project")

    description(~s(If the authenticated user is the project owner:
                   Removes all project to asset lease assignments, then deletes the project itself.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(204, "Success - No Content")
    response(404, "Not Found")
    response(422, "Error")
  end

  def delete(conn, %{"id" => id}) do
    fun = fn _user, _is_owner, _project ->
      with :ok <- Project.delete(id) do
        send_resp(conn, :no_content, "")
      end
    end

    conn.assigns.current_api_user
    |> Controller.ensure_project_access_allowed(id, fun)
  end

  defp convert_primary_asset_id(%{"primary_asset_id" => primary_asset_id} = params, project) do
    %{asset_leases: asset_leases} = Repo.preload(project, :asset_leases)

    lease = Enum.find(asset_leases, &(&1.asset_id == primary_asset_id))

    id = if is_nil(lease), do: "", else: lease.id

    params
    |> Map.delete("primary_asset_id")
    |> Map.put("primary_asset_lease_id", id)
  end

  defp convert_primary_asset_id(params, _project), do: params
end

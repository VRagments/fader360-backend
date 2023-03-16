defmodule DarthWeb.Projects.ProjectLive.FormScenes do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Controller.ProjectScene
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct
  alias Darth.Controller.User
  alias DarthWeb.Components.{FormHeader, FormCheckBox, FormInputField}

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session") do
      {:ok,
       socket
       |> assign(current_user: user)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"project_id" => project_id} = params, _url, socket) do
    socket =
      socket
      |> assign(project_id: project_id)
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"project_scene" => project_scene_params}, socket) do
    save_project_scene(socket, socket.assigns.live_action, project_scene_params)
  end

  defp save_project_scene(socket, :new, params) do
    params =
      params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put("project_id", socket.assigns.project_id)

    socket =
      case ProjectScene.create(params) do
        {:ok, %ProjectSceneStruct{}} ->
          socket
          |> put_flash(:info, "Project scene created successfully")
          |> push_navigate(to: socket.assigns.return_to)

        {:error, reason} ->
          Logger.error("Project Scene creation failed: #{inspect(reason)}")

          socket
          |> put_flash(:info, "Project Scene creation failed")
          |> push_navigate(to: socket.assigns.return_to)
      end

    {:noreply, socket}
  end

  defp save_project_scene(socket, :edit, project_scene_params) do
    case ProjectScene.update(socket.assigns.project_scene, project_scene_params) do
      {:ok, _updated_project_scene} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project scene updated successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp apply_action(socket, :new, %{"project_id" => project_id}) do
    socket
    |> assign(changeset: ProjectSceneStruct.changeset(%ProjectSceneStruct{}))
    |> assign(action_label: "Create")
    |> assign(:return_to, Routes.project_show_path(socket, :show, project_id))
  end

  defp apply_action(socket, :edit, %{"project_scene_id" => project_scene_id, "project_id" => project_id}) do
    case ProjectScene.read(project_scene_id) do
      {:ok, project_scene} ->
        socket
        |> assign(:changeset, ProjectSceneStruct.changeset(project_scene))
        |> assign(:project_scene, project_scene)
        |> assign(action_label: "Update")
        |> assign(
          :return_to,
          Routes.project_scene_show_path(socket, :show, project_id, project_scene_id)
        )

      _ ->
        socket
        |> put_flash(:error, "Unable to fetch project scene")
        |> push_navigate(to: Routes.project_show_path(socket, :show, project_id))
    end
  end
end

defmodule DarthWeb.Projects.ProjectLive.Form do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.User
  alias Darth.Controller.Project
  alias DarthWeb.Components.{FormHeader, FormInputField, FormSelectField}

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
  def handle_params(params, _url, socket) do
    select_options = Ecto.Enum.mappings(ProjectStruct, :visibility)

    socket =
      socket
      |> assign(select_options: select_options)
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"project" => project_params}, socket) do
    save_project(socket, socket.assigns.live_action, project_params)
  end

  defp save_project(socket, :edit, project_params) do
    case Project.update(socket.assigns.project, project_params) do
      {:ok, _updated_project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project updated successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp save_project(socket, :new, params) do
    params =
      params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put("author", socket.assigns.current_user.display_name)

    socket =
      case Project.create(params) do
        {:ok, %ProjectStruct{}} ->
          socket
          |> put_flash(:info, "Project created successfully")
          |> push_navigate(to: socket.assigns.return_to)

        {:error, reason} ->
          Logger.error("Project creation failed: #{inspect(reason)}")

          socket
          |> put_flash(:info, "Project creation failed")
          |> push_navigate(to: socket.assigns.return_to)
      end

    {:noreply, socket}
  end

  defp apply_action(socket, :new, %{"asset_lease_id" => asset_lease_id}) do
    socket
    |> assign(changeset: ProjectStruct.changeset(%ProjectStruct{}))
    |> assign(action_label: "Create")
    |> assign(:return_to, Routes.asset_form_projects_path(socket, :index, asset_lease_id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(changeset: ProjectStruct.changeset(%ProjectStruct{}))
    |> assign(action_label: "Create")
    |> assign(:return_to, Routes.project_index_path(socket, :index))
  end

  defp apply_action(socket, :edit, %{"project_id" => project_id}) do
    case Project.read(project_id) do
      {:ok, project} ->
        socket
        |> assign(:changeset, ProjectStruct.changeset(project))
        |> assign(:project, project)
        |> assign(action_label: "Update")
        |> assign(:return_to, Routes.project_show_path(socket, :show, project_id))

      _ ->
        socket
        |> put_flash(:error, "Unable to fetch project")
        |> push_navigate(to: Routes.project_index_path(socket, :index))
    end
  end
end

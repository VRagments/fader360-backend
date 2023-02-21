defmodule DarthWeb.Projects.ProjectLive.Form do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.User
  alias Darth.Controller.Project

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
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.PageLive.Page))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.PageLive.Page))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    socket =
      socket
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

    case Project.create(params) do
      {:ok, %ProjectStruct{}} ->
        socket =
          socket
          |> put_flash(:info, "Project created successfully")
          |> push_navigate(to: socket.assigns.return_to)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Project creation failed: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:info, "Project creation failed")
          |> push_navigate(to: socket.assigns.return_to)

        {:noreply, socket}
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(changeset: ProjectStruct.changeset(%ProjectStruct{}))
    |> assign(action_label: "Create")
    |> assign(:return_to, Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))
  end

  defp apply_action(socket, :edit, %{"project_id" => project_id}) do
    case Project.read(project_id) do
      {:ok, project} ->
        socket
        |> assign(:changeset, ProjectStruct.changeset(project))
        |> assign(:project, project)
        |> assign(action_label: "Update")
        |> assign(:return_to, Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Show, project_id))

      _ ->
        socket
        |> put_flash(:error, "Unable to fetch project")
        |> push_navigate(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))
    end
  end
end

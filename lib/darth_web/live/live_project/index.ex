defmodule DarthWeb.LiveProject.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.Project

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
      {:ok,
       socket
       |> assign(current_user: user)}
    else
      {:error, reason} ->
        Logger.error("Database Error message: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LivePage.Page))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LivePage.Page))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    query = from(p in ProjectStruct, where: p.user_id == ^socket.assigns.current_user.id)

    case Project.query(params, query, true) do
      %{entries: user_projects} ->
        user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end)
        user_projects_list = get_sorted_user_project_list(user_projects_map)

        socket =
          socket
          |> assign(
            changeset: ProjectStruct.changeset(%ProjectStruct{}),
            user_projects_list: user_projects_list,
            user_projects_map: user_projects_map
          )

        {:noreply, socket}

      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"project" => params}, socket) do
    params =
      params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put("author", socket.assigns.current_user.display_name)

    case Project.create(params) do
      {:ok, %ProjectStruct{}} ->
        socket =
          socket
          |> put_flash(:info, "Project created successfully!!!")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Project creation failed: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:info, "Project creation failed!!!")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_project", %{"ref" => project_id}, socket) do
    case Project.delete(project_id) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Project deleted successfully!!!")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

        {:noreply, socket}

      _ ->
        socket =
          socket
          |> put_flash(:info, "Unable to delete project!!!")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:project_created, _project}, socket) do
    get_updated_socket(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_deleted, _project}, socket) do
    get_updated_socket(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_updated, project}, socket) do
    user_projects_map = Map.put(socket.assigns.user_projects_map, project.id, project)
    user_projects_list = get_sorted_user_project_list(user_projects_map)

    socket =
      socket
      |> assign(user_projects_list: user_projects_list, user_projects_map: user_projects_map)
      |> put_flash(:info, "Project updated!!!")
      |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_socket(socket) do
    with query = from(p in ProjectStruct, where: p.user_id == ^socket.assigns.current_user.id),
         %{entries: user_projects} <- Project.query(%{}, query, true),
         user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end),
         user_projects_list = get_sorted_user_project_list(user_projects_map) do
      {:noreply,
       socket
       |> assign(user_projects_list: user_projects_list, user_projects_map: user_projects_map)}
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

        {:noreply, socket}

      err ->
        Logger.error("Error message: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveProject.Index))

        {:noreply, socket}
    end
  end

  defp get_sorted_user_project_list(user_projects_map) do
    user_projects_map
    |> Map.values()
    |> Enum.sort_by(& &1.inserted_at)
  end
end

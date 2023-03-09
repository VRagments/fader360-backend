defmodule DarthWeb.Projects.ProjectLive.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.Project
  alias DarthWeb.Components.IndexCard
  alias DarthWeb.Components.Header
  alias DarthWeb.Components.Pagination

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
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
    query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id)

    case Project.query(params, query, true) do
      %{query_page: current_page, total_pages: total_pages, entries: user_projects} ->
        user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end)
        user_projects_list = Project.get_sorted_user_project_list(user_projects_map)

        socket =
          socket
          |> assign(
            current_page: current_page,
            total_pages: total_pages,
            user_projects_list: user_projects_list,
            user_projects_map: user_projects_map
          )

        {:noreply, socket}

      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"ref" => project_id}, socket) do
    socket =
      case Project.delete(project_id) do
        :ok ->
          socket
          |> put_flash(:info, "Project deleted successfully")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))

        _ ->
          socket
          |> put_flash(:info, "Unable to delete project")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_created, _project}, socket) do
    get_updated_project_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_deleted, _project}, socket) do
    get_updated_project_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_updated, project}, socket) do
    user_projects_map = Map.put(socket.assigns.user_projects_map, project.id, project)
    user_projects_list = Project.get_sorted_user_project_list(user_projects_map)

    socket =
      socket
      |> assign(user_projects_list: user_projects_list, user_projects_map: user_projects_map)
      |> put_flash(:info, "Project updated")
      |> push_patch(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_project_list(socket) do
    socket =
      with query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id),
           %{entries: user_projects} <- Project.query(%{}, query, true),
           user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end),
           user_projects_list = Project.get_sorted_user_project_list(user_projects_map) do
        socket
        |> assign(user_projects_list: user_projects_list, user_projects_map: user_projects_map)
      else
        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))

        err ->
          Logger.error("Error message: #{inspect(err)}")

          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))
      end

    {:noreply, socket}
  end

  defp render_audio_card(assigns) do
    ~H"""
    <IndexCard.render show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show,
      @user_project.id)} title={@user_project.name} visibility={@user_project.visibility}
      subtitle={@user_project.author} button_one_label="Edit" button_two_label="Delete"
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      button_one_route={Routes.project_form_path(@socket, :edit, @user_project.id)}
      button_one_action="edit" button_two_action="delete"
      button_two_phx_value_ref={@user_project.id} />
    """
  end

  defp render_image_card(assigns) do
    ~H"""
    <IndexCard.render show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show,
      @user_project.id)} title={@user_project.name} visibility={@user_project.visibility}
      subtitle={@user_project.author} button_one_label="Edit" button_two_label="Delete"
      image_source={@user_project.primary_asset.thumbnail_image}
      button_one_route={Routes.project_form_path(@socket, :edit, @user_project.id)}
      button_one_action="edit" button_two_action="delete"
      button_two_phx_value_ref={@user_project.id} />
    """
  end

  defp render_default_card(assigns) do
    ~H"""
    <IndexCard.render show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show,
      @user_project.id)} title={@user_project.name} visibility={@user_project.visibility}
      subtitle={@user_project.author} button_one_label="Edit" button_two_label="Delete"
      image_source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg" )}
      button_one_route={Routes.project_form_path(@socket, :edit, @user_project.id)}
      button_one_action="edit" button_two_action="delete"
      button_two_phx_value_ref={@user_project.id} />
    """
  end
end

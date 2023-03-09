defmodule DarthWeb.Projects.ProjectLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.Project
  alias Darth.Model.Project, as: ProjectStruct
  alias DarthWeb.Components.Header
  alias DarthWeb.Components.Show

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets") do
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
        Logger.error("Error message: User not found in Database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.PageLive.Page))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"project_id" => project_id}, _url, socket) do
    with {:ok, project} <- Project.read(project_id, true),
         true <- project.user_id == socket.assigns.current_user.id do
      {:noreply, socket |> assign(project: project, changeset: ProjectStruct.changeset(project))}
    else
      {:error, reason} ->
        Logger.error("Error message: Database error while fetching user project: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch project")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))

        {:noreply, socket}

      false ->
        Logger.error(
          "Error message: Database error while fetching user project: Current user don't have access to this project"
        )

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this project")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))

        {:noreply, socket}

      err ->
        Logger.error("Error message: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_visibility", %{"project" => project_params}, socket) do
    case Project.update(socket.assigns.project, project_params) do
      {:ok, _updated_project} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:project_deleted, project}, socket) do
    socket =
      if socket.assigns.project.id == project.id do
        socket
        |> put_flash(:info, "Project deleted successfully")
        |> push_navigate(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Index))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_updated, project}, socket) do
    socket =
      if socket.assigns.project.id == project.id do
        socket
        |> put_flash(:info, "Project updated")
        |> push_patch(to: Routes.live_path(socket, DarthWeb.Projects.ProjectLive.Show, project.id))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp render_project_with_audio_primary_asset(assigns) do
    ~H"""
    <Show.render type="project" author={@project.author} visibility={@project.visibility}
      updated_at={NaiveDateTime.to_date(@project.updated_at)}
      source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )} changeset={@changeset} />
    """
  end

  defp render_project_with_primary_asset(assigns) do
    ~H"""
    <Show.render type="project" author={@project.author} visibility={@project.visibility}
      updated_at={NaiveDateTime.to_date(@project.updated_at)}
      source={@project.primary_asset.thumbnail_image} changeset={@changeset}/>
    """
  end

  defp render_project_with_no_primary_asset(assigns) do
    ~H"""
    <Show.render type="project" author={@project.author} visibility={@project.visibility}
      updated_at={NaiveDateTime.to_date(@project.updated_at)}
      source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg" )} changeset={@changeset}/>
    """
  end
end

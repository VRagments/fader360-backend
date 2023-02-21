defmodule DarthWeb.Assets.AssetLive.FormProjects do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Controller.User
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Project
  alias Darth.Controller.Asset
  alias DarthWeb.Components.Header
  alias DarthWeb.Components.ShowCard
  alias DarthWeb.Components.Pagination

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         upload_file_size = Application.fetch_env!(:darth, :upload_file_size),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases") do
      {:ok,
       socket
       |> assign(current_user: user)
       |> assign(:uploaded_files, [])
       |> allow_upload(:media, accept: ~w(audio/* video/* image/*), max_entries: 1, max_file_size: upload_file_size)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"asset_lease_id" => asset_lease_id} = params, _url, socket) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         true <- AssetLease.has_user?(asset_lease, socket.assigns.current_user.id),
         query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id),
         %{query_page: current_page, total_pages: total_pages, entries: user_projects} <-
           Project.query(params, query, true),
         user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end),
         user_projects_list = Project.get_sorted_user_project_list(user_projects_map) do
      {:noreply,
       socket
       |> assign(
         asset_lease: asset_lease,
         current_page: current_page,
         total_pages: total_pages,
         user_projects_map: user_projects_map,
         user_projects_list: user_projects_list
       )}
    else
      false ->
        Logger.error("Error message: Current user don't have access to this Asset")

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this Asset")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:noreply, socket}

      {:error, %Ecto.QueryError{} = query_error} ->
        Logger.error(
          "Error message from MediaVerse: Database error while fetching asset via asset leases: #{inspect(query_error)}"
        )

        socket =
          socket
          |> put_flash(:error, "Error while fetching projects")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Error while fetching asset and projects")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:noreply, socket}

      nil ->
        Logger.error("Error message: Asset not found in database")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("assign", %{"ref" => user_project_id}, socket) do
    user_project = Map.get(socket.assigns.user_projects_map, user_project_id)

    socket =
      case AssetLease.assign_project(socket.assigns.asset_lease, socket.assigns.current_user, user_project) do
        {:ok, _asset_lease} ->
          socket =
            socket
            |> put_flash(:info, "Asset added to project")
            |> push_patch(
              to:
                Routes.live_path(socket, DarthWeb.Assets.AssetLive.FormProjects, socket.assigns.asset_lease.id,
                  page: socket.assigns.current_page
                )
            )

          socket

        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket =
            socket
            |> put_flash(:error, "Unable add asset to project")
            |> push_patch(
              to:
                Routes.live_path(socket, DarthWeb.Assets.AssetLive.FormProjects, socket.assigns.asset_lease.id,
                  page: socket.assigns.current_page
                )
            )

          socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("unassign", %{"ref" => user_project_id}, socket) do
    user_project = Map.get(socket.assigns.user_projects_map, user_project_id)

    socket =
      with {:ok, asset_lease} <-
             AssetLease.unassign_project(socket.assigns.asset_lease, socket.assigns.current_user, user_project),
           {:ok, _project} <- Project.unassign_primary_asset_lease(user_project, asset_lease) do
        socket =
          socket
          |> put_flash(:info, "Asset removed from project")
          |> push_patch(
            to:
              Routes.live_path(socket, DarthWeb.Assets.AssetLive.FormProjects, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )

        socket
      else
        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket =
            socket
            |> put_flash(:error, "Unable to remove asset from project")
            |> push_patch(
              to:
                Routes.live_path(socket, DarthWeb.Assets.AssetLive.FormProjects, socket.assigns.asset_lease.id,
                  page: socket.assigns.current_page
                )
            )

          socket
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
      |> push_patch(
        to:
          Routes.live_path(socket, DarthWeb.Assets.AssetLive.FormProjects, socket.assigns.asset_lease.id,
            page: socket.assigns.current_page
          )
      )

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_project_list(socket) do
    with query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id),
         %{entries: user_projects} <- Project.query(%{}, query, true),
         user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end),
         user_projects_list = Project.get_sorted_user_project_list(user_projects_map) do
      {:noreply,
       socket
       |> assign(user_projects_list: user_projects_list, user_projects_map: user_projects_map)}
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_patch(
            to:
              Routes.live_path(socket, DarthWeb.Assets.AssetLive.FormProjects, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )

        {:noreply, socket}

      err ->
        Logger.error("Error message: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_patch(
            to:
              Routes.live_path(socket, DarthWeb.Assets.AssetLive.FormProjects, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )

        {:noreply, socket}
    end
  end

  defp render_added_audio_project_card(assigns) do
    ~H"""
    <ShowCard.render title={@user_project.name} subtitle={@user_project.visibility}
      show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show, @user_project.id)}
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      button_one_action="unassign" button_one_label="Remove from Project"
      button_one_phx_value_ref={@user_project.id} state="Asset added to Project"/>
    """
  end

  defp render_added_image_project_card(assigns) do
    ~H"""
    <ShowCard.render title={@user_project.name} subtitle={@user_project.visibility}
      show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show, @user_project.id)}
      image_source={@user_project.primary_asset.thumbnail_image} button_one_action="unassign"
      button_one_label="Remove from Project" button_one_phx_value_ref={@user_project.id}
      state="Asset added to Project"/>
    """
  end

  defp render_added_default_project_card(assigns) do
    ~H"""
    <ShowCard.render title={@user_project.name} subtitle={@user_project.visibility}
      show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show, @user_project.id)}
      image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
      button_one_action="unassign" button_one_label="Remove from Project"
      button_one_phx_value_ref={@user_project.id} state="Asset added to Project"/>
    """
  end

  defp render_available_audio_project_card(assigns) do
    ~H"""
    <ShowCard.render title={@user_project.name} subtitle={@user_project.visibility}
      show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show, @user_project.id)}
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      button_one_action="assign" button_one_label="Add to Project"
      button_one_phx_value_ref={@user_project.id} />
    """
  end

  defp render_available_image_project_card(assigns) do
    ~H"""
    <ShowCard.render title={@user_project.name} subtitle={@user_project.visibility}
      show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show, @user_project.id)}
      image_source={@user_project.primary_asset.thumbnail_image} button_one_action="assign"
      button_one_label="Add to Project" button_one_phx_value_ref={@user_project.id} />
    """
  end

  defp render_available_default_project_card(assigns) do
    ~H"""
    <ShowCard.render title={@user_project.name} subtitle={@user_project.visibility}
      show_path={Routes.live_path(@socket, DarthWeb.Projects.ProjectLive.Show, @user_project.id)}
      image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
      button_one_action="assign" button_one_label="Add to Project"
      button_one_phx_value_ref={@user_project.id} />
    """
  end
end
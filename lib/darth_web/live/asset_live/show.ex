defmodule DarthWeb.AssetLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Project

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
      {:ok, socket |> assign(current_user: user)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.AssetLive.Index))

        {:ok, socket}

      nil ->
        Logger.error("Error message from MediaVerse: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.AssetLive.Index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"asset_lease_id" => asset_lease_id}, _url, socket) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         true <- AssetLease.has_user?(asset_lease, socket.assigns.current_user.id),
         query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id),
         %{entries: user_projects} <- Project.query(%{}, query, true),
         user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end),
         user_projects_list = Project.get_sorted_user_project_list(user_projects_map) do
      {:noreply,
       socket
       |> assign(
         asset_lease: asset_lease,
         user_projects_map: user_projects_map,
         user_projects_list: user_projects_list
       )}
    else
      false ->
        Logger.error("Error message: Current user don't have access to this Asset")

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this Asset")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.AssetLive.Index))

        {:noreply, socket}

      {:error, %Ecto.QueryError{} = query_error} ->
        Logger.error(
          "Error message from MediaVerse: Database error while fetching asset via asset leases: #{inspect(query_error)}"
        )

        socket =
          socket
          |> put_flash(:error, "Error while fetching projects")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.AssetLive.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Error while fetching asset and projects")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.AssetLive.Index))

        {:noreply, socket}

      nil ->
        Logger.error("Error message: Asset not found in database")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.AssetLive.Index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("assign_project", %{"ref" => user_project_id}, socket) do
    user_project = Map.get(socket.assigns.user_projects_map, user_project_id)

    socket =
      case AssetLease.assign_project(socket.assigns.asset_lease, socket.assigns.current_user, user_project) do
        {:ok, _asset_lease} ->
          socket =
            socket
            |> put_flash(:info, "Asset added to project")
            |> push_patch(to: Routes.live_path(socket, DarthWeb.AssetLive.Show, socket.assigns.asset_lease.id))

          socket

        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket =
            socket
            |> put_flash(:error, "Unable add asset to project")
            |> push_patch(to: Routes.live_path(socket, DarthWeb.ProjectLive.Show, socket.assigns.project.id))

          socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("unassign_project", %{"ref" => user_project_id}, socket) do
    user_project = Map.get(socket.assigns.user_projects_map, user_project_id)

    socket =
      with {:ok, asset_lease} <-
             AssetLease.unassign_project(socket.assigns.asset_lease, socket.assigns.current_user, user_project),
           {:ok, _project} <- Project.unassign_primary_asset_lease(user_project, asset_lease) do
        socket =
          socket
          |> put_flash(:info, "Asset removed from project")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.AssetLive.Show, asset_lease.id))

        socket
      else
        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket =
            socket
            |> put_flash(:error, "Unable to remove asset from project")
            |> push_patch(to: Routes.live_path(socket, DarthWeb.AssetLive.Show, socket.assigns.asset_lease.id))

          socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, asset}, socket) do
    socket =
      if socket.assigns.asset_lease.asset.id == asset.id do
        updated_asset_lease =
          socket.assigns.asset_lease
          |> Map.put(:asset, asset)

        assign(socket, asset_lease: updated_asset_lease)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, asset}, socket) do
    socket =
      if socket.assigns.asset_lease.asset.id == asset.id do
        socket
        |> put_flash(:info, "Asset deleted successfully")
        |> push_navigate(to: Routes.live_path(socket, DarthWeb.AssetLive.Index))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:assigned_project, asset_lease}, socket) do
    socket =
      if socket.assigns.asset_lease.id == asset_lease.id do
        socket
        |> assign(asset_lease: asset_lease)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:unassigned_project, asset_lease}, socket) do
    socket =
      if socket.assigns.asset_lease.id == asset_lease.id do
        socket
        |> assign(asset_lease: asset_lease)
      else
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
      |> push_patch(to: Routes.live_path(socket, DarthWeb.AssetLive.Show, socket.assigns.asset_lease.id))

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def get_width(attributes) do
    Map.get(attributes, "width")
  end

  def get_height(attributes) do
    Map.get(attributes, "height")
  end

  def get_file_size(attributes) do
    size = Map.get(attributes, "file_size")

    (size * 0.000001)
    |> Float.round(2)
    |> inspect
  end

  def get_duration(attributes) do
    duration = Map.get(attributes, "duration")

    case duration > 0 do
      true ->
        duration
        |> Float.round(2)
        |> inspect

      false ->
        duration
    end
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
          |> push_patch(to: Routes.live_path(socket, DarthWeb.AssetLive.Show, socket.assigns.asset_lease.id))

        {:noreply, socket}

      err ->
        Logger.error("Error message: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.AssetLive.Show, socket.assigns.asset_lease.id))

        {:noreply, socket}
    end
  end
end

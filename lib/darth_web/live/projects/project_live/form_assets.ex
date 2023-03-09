defmodule DarthWeb.Projects.ProjectLive.FormAssets do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Controller.User
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Asset
  alias Darth.Controller.Project
  alias Darth.Model.User, as: UserStruct
  alias DarthWeb.Components.ShowCard
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
  def handle_params(%{"project_id" => project_id} = params, _url, socket) do
    with {:ok, project} <- Project.read(project_id, true),
         %{query_page: current_page, total_pages: total_pages, entries: asset_leases} <-
           AssetLease.query_by_user(socket.assigns.current_user.id, params, false),
         asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end),
         asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map),
         true <- project.user_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> assign(
         project: project,
         asset_leases_map: asset_leases_map,
         asset_leases_list: asset_leases_list,
         current_page: current_page,
         total_pages: total_pages
       )}
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
  def handle_event("assign", %{"ref" => asset_lease_id}, socket) do
    socket =
      with asset_lease = Map.get(socket.assigns.asset_leases_map, asset_lease_id),
           {:ok, _asset_lease} <-
             AssetLease.assign_project(asset_lease, socket.assigns.current_user, socket.assigns.project) do
        socket
        |> put_flash(:info, "Project assigned to asset")
        |> push_patch(
          to:
            Routes.live_path(socket, DarthWeb.Projects.ProjectLive.FormAssets, socket.assigns.project.id,
              page: socket.assigns.current_page
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to assign project to the asset")
          |> push_patch(
            to:
              Routes.live_path(socket, DarthWeb.Projects.ProjectLive.FormAssets, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("unassign", %{"ref" => asset_lease_id}, socket) do
    socket =
      with asset_lease = Map.get(socket.assigns.asset_leases_map, asset_lease_id),
           {:ok, asset_lease} <-
             AssetLease.unassign_project(asset_lease, socket.assigns.current_user, socket.assigns.project),
           {:ok, project} <- Project.unassign_primary_asset_lease(socket.assigns.project, asset_lease) do
        socket
        |> put_flash(:info, "Asset removed from project")
        |> push_patch(
          to:
            Routes.live_path(socket, DarthWeb.Projects.ProjectLive.FormAssets, project.id,
              page: socket.assigns.current_page
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error message:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to remove asset from the project")
          |> push_patch(
            to:
              Routes.live_path(socket, DarthWeb.Projects.ProjectLive.FormAssets, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("make_primary", %{"ref" => asset_lease_id}, socket) do
    socket =
      with {:ok, project} <- Project.update(socket.assigns.project, %{primary_asset_lease_id: asset_lease_id}),
           {:ok, project} <- Project.read(project.id) do
        socket
        |> assign(project: project)
        |> put_flash(:info, "Project primary asset updated")
        |> push_patch(
          to:
            Routes.live_path(socket, DarthWeb.Projects.ProjectLive.FormAssets, project.id,
              page: socket.assigns.current_page
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error message:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to update the primary asset")
          |> push_patch(
            to:
              Routes.live_path(socket, DarthWeb.Projects.ProjectLive.FormAssets, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:assigned_project, asset_lease}, socket) do
    asset_leases_map = Map.put(socket.assigns.asset_leases_map, asset_lease.id, asset_lease)
    asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

    {:noreply, socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: asset_leases_map)}
  end

  @impl Phoenix.LiveView
  def handle_info({:unassigned_project, asset_lease}, socket) do
    asset_leases_map = Map.put(socket.assigns.asset_leases_map, asset_lease.id, asset_lease)
    asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

    {:noreply, socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: asset_leases_map)}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, asset}, socket) do
    asset_leases_map = socket.assigns.asset_leases_map

    asset_lease_tuple = asset_leases_map |> Enum.find(fn {_, value} -> asset.id == value.asset.id end)

    socket =
      if is_nil(asset_lease_tuple) do
        socket
      else
        {_, asset_lease} = asset_lease_tuple
        updated_asset_lease = Map.put(asset_lease, :asset, asset)
        updated_asset_leases_map = Map.put(asset_leases_map, updated_asset_lease.id, updated_asset_lease)
        asset_leases_list = Asset.get_sorted_asset_lease_list(updated_asset_leases_map)
        socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: updated_asset_leases_map)
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_created, _asset_lease}, socket) do
    get_updated_asset_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, _asset}, socket) do
    get_updated_asset_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_asset_list(socket) do
    socket =
      case AssetLease.query_by_user(socket.assigns.current_user.id, %{}, false) do
        %{entries: asset_leases} ->
          asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end)
          asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

          socket
          |> assign(asset_leases_list: asset_leases_list, asset_leases_map: asset_leases_map)

        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Database error while fetching asset via asset leases: #{inspect(query_error)}")

          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))

        err ->
          Logger.error("Error message from MediaVerse: #{inspect(err)}")

          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.Assets.AssetLive.Index))
      end

    {:noreply, socket}
  end

  defp render_added_audio_card_with_one_button(assigns) do
    ~H"""
    <ShowCard.render title={@asset_lease.asset.name} subtitle={@asset_lease.asset.media_type}
      show_path={Routes.live_path(@socket, DarthWeb.Assets.AssetLive.Show, @asset_lease.id)}
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      button_one_action="unassign" button_one_label="Remove"
      button_one_phx_value_ref={@asset_lease.id} state="Asset added to Project"/>
    """
  end

  defp render_added_audio_card_with_two_buttons(assigns) do
    ~H"""
    <ShowCard.render title={@asset_lease.asset.name} subtitle={@asset_lease.asset.media_type}
      show_path={Routes.live_path(@socket, DarthWeb.Assets.AssetLive.Show, @asset_lease.id)}
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      button_one_action="unassign" button_one_label="Remove"
      button_one_phx_value_ref={@asset_lease.id} button_two_action="make_primary"
      button_two_label="Make primary" button_two_phx_value_ref={@asset_lease.id} state="Asset added to Project"/>
    """
  end

  defp render_added_asset_card_with_one_button(assigns) do
    ~H"""
    <ShowCard.render title={@asset_lease.asset.name} subtitle={@asset_lease.asset.media_type}
    show_path={Routes.live_path(@socket, DarthWeb.Assets.AssetLive.Show, @asset_lease.id)}
    image_source={@asset_lease.asset.thumbnail_image} button_one_action="unassign"
    button_one_label="Remove" button_one_phx_value_ref={@asset_lease.id} state="Asset added to Project"/>
    """
  end

  defp render_added_asset_card_with_two_buttons(assigns) do
    ~H"""
    <ShowCard.render title={@asset_lease.asset.name} subtitle={@asset_lease.asset.media_type}
      show_path={Routes.live_path(@socket, DarthWeb.Assets.AssetLive.Show, @asset_lease.id)}
      image_source={@asset_lease.asset.thumbnail_image} button_one_action="unassign"
      button_one_label="Remove" button_one_phx_value_ref={@asset_lease.id}
      button_two_action="make_primary" button_two_label="Make primary"
      button_two_phx_value_ref={@asset_lease.id} state="Asset added to Project" />
    """
  end

  defp render_available_audio_card_with_one_button(assigns) do
    ~H"""
    <ShowCard.render title={@asset_lease.asset.name} subtitle={@asset_lease.asset.media_type}
      show_path={Routes.live_path(@socket, DarthWeb.Assets.AssetLive.Show, @asset_lease.id)}
      image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      button_one_action="assign" button_one_label="Add"
      button_one_phx_value_ref={@asset_lease.id} />
    """
  end

  defp render_available_asset_card_with_one_button(assigns) do
    ~H"""
    <ShowCard.render title={@asset_lease.asset.name} subtitle={@asset_lease.asset.media_type}
      show_path={Routes.live_path(@socket, DarthWeb.Assets.AssetLive.Show, @asset_lease.id)}
      image_source={@asset_lease.asset.thumbnail_image} button_one_action="assign"
      button_one_label="Add" button_one_phx_value_ref={@asset_lease.id} />
    """
  end
end

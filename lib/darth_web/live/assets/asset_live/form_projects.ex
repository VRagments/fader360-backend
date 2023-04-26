defmodule DarthWeb.Assets.AssetLive.FormProjects do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Controller.User
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Model.AssetLease, as: AssetLeaseStruct
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Project
  alias Darth.Controller.Asset

  alias DarthWeb.Components.{
    Header,
    ShowCard,
    Pagination,
    EmptyState,
    CardButtons,
    HeaderButtons
  }

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
       |> allow_upload(:media,
         accept: ~w(audio/* video/* image/*),
         max_entries: 1,
         max_file_size: upload_file_size
       )}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.asset_index_path(socket, :index))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.asset_index_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"asset_lease_id" => asset_lease_id} = params, _url, socket) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         true <- AssetLease.has_user?(asset_lease, socket.assigns.current_user.id),
         query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id),
         %{query_page: current_page, total_pages: total_pages, entries: user_projects} <-
           Project.query(params, query, true) do
      map_with_all_links = map_with_all_links(socket, asset_lease, total_pages)
      user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end)
      user_projects_list = Project.get_sorted_user_project_list(user_projects_map)

      {:noreply,
       socket
       |> assign(
         asset_lease: asset_lease,
         current_page: current_page,
         total_pages: total_pages,
         user_projects_map: user_projects_map,
         user_projects_list: user_projects_list,
         map_with_all_links: map_with_all_links
       )}
    else
      false ->
        Logger.error("Error message: Current user don't have access to this Asset")

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this Asset")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}

      {:error, %Ecto.QueryError{} = query_error} ->
        Logger.error(
          "Error message from MediaVerse: Database error while fetching asset via asset leases: #{inspect(query_error)}"
        )

        socket =
          socket
          |> put_flash(:error, "Error while fetching projects")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Error while fetching asset and projects")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}

      nil ->
        Logger.error("Error message: Asset not found in database")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("assign", %{"ref" => user_project_id}, socket) do
    user_project = Map.get(socket.assigns.user_projects_map, user_project_id)

    socket =
      case AssetLease.assign_project(
             socket.assigns.asset_lease,
             socket.assigns.current_user,
             user_project
           ) do
        {:ok, _asset_lease} ->
          socket
          |> put_flash(:info, "Asset added to project")
          |> push_patch(
            to:
              Routes.asset_form_projects_path(socket, :index, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )

        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable add asset to project")
          |> push_patch(
            to:
              Routes.asset_form_projects_path(socket, :index, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("unassign", %{"ref" => user_project_id}, socket) do
    user_project = Map.get(socket.assigns.user_projects_map, user_project_id)

    socket =
      with {:ok, asset_lease} <-
             AssetLease.unassign_project(
               socket.assigns.asset_lease,
               socket.assigns.current_user,
               user_project
             ),
           {:ok, _project} <- Project.unassign_primary_asset_lease(user_project, asset_lease) do
        socket
        |> put_flash(:info, "Asset removed from project")
        |> push_patch(
          to:
            Routes.asset_form_projects_path(socket, :index, socket.assigns.asset_lease.id,
              page: socket.assigns.current_page
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to remove asset from project")
          |> push_patch(
            to:
              Routes.asset_form_projects_path(socket, :index, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )
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
          Routes.asset_form_projects_path(socket, :index, socket.assigns.asset_lease.id,
            page: socket.assigns.current_page
          )
      )

    {:noreply, socket}
  end

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
          |> push_patch(
            to:
              Routes.asset_form_projects_path(socket, :index, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )

        err ->
          Logger.error("Error message: #{inspect(err)}")

          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_patch(
            to:
              Routes.asset_form_projects_path(socket, :index, socket.assigns.asset_lease.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  defp map_with_all_links(socket, asset_lease, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.asset_form_projects_path(socket, :index, asset_lease.id, page: page)}
    end)
  end

  defp render_added_audio_project_card(assigns) do
    ~H"""
    <ShowCard.render
      title={@user_project.name}
      path={Routes.project_show_path(@socket, :show, @user_project.id)}
      source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      subtitle={@user_project.visibility}
      status="Asset added to Project"
    >
      <CardButtons.render
        buttons={[
          {
            :unassign,
            phx_value_ref: @user_project.id,
            label: "Remove Project"
          }
        ]}
      />
    </ShowCard.render>
    """
  end

  defp render_added_image_project_card(assigns) do
    ~H"""
    <ShowCard.render
      title={@user_project.name}
      path={Routes.project_show_path(@socket, :show, @user_project.id)}
      source={@user_project.primary_asset.thumbnail_image}
      subtitle={@user_project.visibility}
      status="Asset added to Project"
    >
      <CardButtons.render
        buttons={[
          {
            :unassign,
            phx_value_ref: @user_project.id,
            label: "Remove Project"
          }
        ]}
      />
    </ShowCard.render>
    """
  end

  defp render_added_default_project_card(assigns) do
    ~H"""
    <ShowCard.render
      title = {@user_project.name}
      path={Routes.project_show_path(@socket, :show, @user_project.id)}
      source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
      subtitle={@user_project.visibility}
      status="Asset added to Project"
    >
      <CardButtons.render
        buttons={[
          {
            :unassign,
            phx_value_ref: @user_project.id,
            label: "Remove Project"
          }
        ]}
      />
    </ShowCard.render>
    """
  end

  defp render_available_audio_project_card(assigns) do
    ~H"""
    <ShowCard.render
      title={@user_project.name}
      path={Routes.project_show_path(@socket, :show, @user_project.id)}
      source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
      subtitle={@user_project.visibility}
    >
      <CardButtons.render
        buttons={[
          {
            :assign,
            phx_value_ref: @user_project.id,
            label: "Add to Project"
          }
        ]}
      />
    </ShowCard.render>
    """
  end

  defp render_available_image_project_card(assigns) do
    ~H"""
    <ShowCard.render
      title={@user_project.name}
      path={Routes.project_show_path(@socket, :show, @user_project.id)}
      source={@user_project.primary_asset.thumbnail_image}
      subtitle={@user_project.visibility}
    >
      <CardButtons.render
        buttons={[
          {
            :assign,
            phx_value_ref: @user_project.id,
            label: "Add to Project"
          }
        ]}
      />
    </ShowCard.render>
    """
  end

  defp render_available_default_project_card(assigns) do
    ~H"""
    <ShowCard.render
      title={@user_project.name}
      path={Routes.project_show_path(@socket, :show, @user_project.id)}
      source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
      subtitle={@user_project.visibility}
    >
      <CardButtons.render
        buttons={[
          {
            :assign,
            phx_value_ref: @user_project.id,
            label: "Add to Project"
          }
        ]}
      />
    </ShowCard.render>
    """
  end

  defp render_project_show_card(assigns) do
    if AssetLease.is_part_of_project?(assigns.asset_lease, assigns.user_project) do
      render_added_project_show_card(assigns)
    else
      render_available_project_show_card(assigns)
    end
  end

  defp render_available_project_show_card(assigns) do
    case assigns.user_project.primary_asset_lease do
      nil -> render_available_default_project_card(assigns)
      %AssetLeaseStruct{} -> render_available_media_card(assigns)
    end
  end

  defp render_available_media_card(assigns) do
    media_type = Asset.normalized_media_type(assigns.user_project.primary_asset_lease.asset.media_type)

    case media_type do
      :audio -> render_available_audio_project_card(assigns)
      :image -> render_available_image_project_card(assigns)
      :video -> render_available_image_project_card(assigns)
    end
  end

  defp render_added_project_show_card(assigns) do
    case assigns.user_project.primary_asset_lease do
      nil -> render_added_default_project_card(assigns)
      %AssetLeaseStruct{} -> render_added_media_card(assigns)
    end
  end

  defp render_added_media_card(assigns) do
    media_type = Asset.normalized_media_type(assigns.user_project.primary_asset_lease.asset.media_type)

    case media_type do
      :audio -> render_added_audio_project_card(assigns)
      :image -> render_added_image_project_card(assigns)
      :video -> render_added_image_project_card(assigns)
    end
  end
end

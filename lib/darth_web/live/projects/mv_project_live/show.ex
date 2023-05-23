defmodule DarthWeb.Projects.MvProjectLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Controller.{User, Project, Asset}
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.MvApiClient

  alias DarthWeb.Components.{
    Header,
    Stat,
    EmptyState,
    IndexCard,
    CardButtons,
    HeaderButtons,
    Pagination,
    ShowDefault
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
      {:ok, socket |> assign(current_user: user, mv_token: mv_token)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"mv_project_id" => mv_project_id} = params, _url, socket) do
    mv_token = socket.assigns.mv_token
    mv_node = socket.assigns.current_user.mv_node
    user_id = socket.assigns.current_user.id

    query =
      ProjectStruct
      |> where([p], p.user_id == ^user_id and p.mv_project_id == ^mv_project_id)

    socket =
      with {:ok, mv_project} <- MvApiClient.show_project(mv_node, mv_token, mv_project_id),
           %{query_page: current_page, total_pages: total_pages, entries: fader_projects} <-
             Project.query(params, query, true) do
        user_projects_map = Map.new(fader_projects, fn up -> {up.id, up} end)
        fader_projects_list = Project.get_sorted_user_project_list(user_projects_map)
        map_with_all_links = map_with_all_links(socket, mv_project_id, total_pages)
        [updated_at, _] = String.split(Map.get(mv_project, "updatedAt"), "T")

        socket
        |> assign(
          mv_project: mv_project,
          updated_at: updated_at,
          fader_projects: fader_projects_list,
          current_page: current_page,
          total_pages: total_pages,
          map_with_all_links: map_with_all_links
        )
      else
        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

          socket =
            socket
            |> put_flash(:error, "Unable to fetch projects")
            |> push_navigate(to: Routes.mv_project_index_path(socket, :index))

          {:noreply, socket}

        {:ok, %{"message" => message}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

          socket
          |> put_flash(:error, "Error fetching the MediaVerse project:#{inspect(message)}")
          |> push_navigate(to: Routes.mv_project_index_path(socket, :index))

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Server response error")
          |> push_navigate(to: Routes.mv_project_index_path(socket, :index))

        {:error, reason} ->
          Logger.error("Error while handling event add_mv_project: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Error while fetching MediaVerse project")
          |> push_navigate(to: Routes.mv_project_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("add_mv_project", %{"ref" => mv_project_id}, socket) do
    mv_project = socket.assigns.mv_project
    current_user = socket.assigns.current_user
    mv_node = current_user.mv_node
    mv_token = socket.assigns.mv_token
    user_params = %{mv_node: mv_node, mv_token: mv_token, current_user: current_user}

    socket =
      with {:ok, project_struct} <- Project.build_params_create_new_project(current_user, mv_project),
           {:ok, mv_asset_list} <- Project.fetch_and_filter_mv_project_assets(mv_node, mv_token, mv_project_id),
           {:ok, asset_leases} <- Project.add_project_assets_to_fader(user_params, mv_asset_list, project_struct) do
        Project.download_project_assets(user_params, asset_leases)

        socket
        |> put_flash(:info, "Added this Mediaverse project to Fader")
        |> push_patch(to: Routes.mv_project_show_path(socket, :show, Map.get(socket.assigns.mv_project, "id")))
      else
        {:error, reason} ->
          Logger.error("Error while handling event add_mv_project: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Error while fetching MediaVerse project")
          |> push_patch(to: Routes.mv_project_show_path(socket, :show, Map.get(socket.assigns.mv_project, "id")))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"ref" => project_id}, socket) do
    socket =
      case Project.delete(project_id) do
        :ok ->
          socket
          |> put_flash(:info, "Fader project deleted successfully")
          |> push_patch(
            to:
              Routes.mv_project_show_path(
                socket,
                :show,
                Map.get(socket.assigns.mv_project, "id", page: socket.assigns.current_page)
              )
          )

        _ ->
          socket
          |> put_flash(:info, "Unable to delete project")
          |> push_patch(
            to:
              Routes.mv_project_show_path(
                socket,
                :show,
                Map.get(socket.assigns.mv_project, "id", page: socket.assigns.current_page)
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
    mv_project_id = Map.get(socket.assigns.mv_project, "id")
    fader_projects_map = Map.put(socket.assigns.user_projects_map, project.id, project)
    fader_projects_list = Project.get_sorted_user_project_list(fader_projects_map)

    socket =
      socket
      |> assign(fader_projects: fader_projects_list, fader_projects_map: fader_projects_map)
      |> put_flash(:info, "Project updated")
      |> push_patch(
        to: Routes.mv_project_show_path(socket, :show, mv_project_id, page: socket.assigns.current_page)
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_project_list(socket) do
    mv_project_id = Map.get(socket.assigns.mv_project, "id")
    user_id = socket.assigns.current_user.id

    query =
      ProjectStruct
      |> where(
        [p],
        p.user_id == ^user_id and p.mv_project_id == ^mv_project_id
      )

    socket =
      case Project.query(%{}, query, true) do
        %{entries: fader_projects} ->
          user_projects_map = Map.new(fader_projects, fn up -> {up.id, up} end)
          fader_projects_list = Project.get_sorted_user_project_list(user_projects_map)

          socket
          |> assign(fader_projects: fader_projects_list)

        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

          socket =
            socket
            |> put_flash(:error, "Unable to fetch projects")
            |> push_patch(
              to: Routes.mv_project_show_path(socket, :show, mv_project_id, page: socket.assigns.current_page)
            )

          {:noreply, socket}

        error ->
          Logger.error("Error while updating project list: #{inspect(error)}")

          socket
          |> put_flash(:error, "Error while fetching MediaVerse project")
          |> push_patch(
            to: Routes.mv_project_show_path(socket, :show, mv_project_id, page: socket.assigns.current_page)
          )
      end

    {:noreply, socket}
  end

  defp map_with_all_links(socket, mv_project_id, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.mv_project_show_path(socket, :show, mv_project_id, page: page)}
    end)
  end

  defp render_project_stats(assigns) do
    ~H"""
      <Stat.render
        title="Author"
        value={Map.get(@project, "author")}
      />
      <Stat.render
        title="Your role"
        value={Map.get(@project, "ownUserRole")}
      />
      <Stat.render
        title="Other Users"
        value={inspect(Map.get(@project, "userNames"))}
      />
      <Stat.render
        title="Last Updated at"
        value={@updated_at}
      />
    """
  end

  defp render_project_card(assigns) do
    if Project.has_primary_asset_lease?(assigns.user_project) do
      render_project_media_card(assigns)
    else
      render_default_card(assigns)
    end
  end

  defp render_project_media_card(assigns) do
    media_type = Asset.normalized_media_type(assigns.user_project.primary_asset.media_type)

    case media_type do
      :audio -> render_audio_card(assigns)
      :video -> render_image_card(assigns)
      :image -> render_image_card(assigns)
    end
  end

  defp render_audio_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_show_path(@socket, :show, @user_project.id)}
        title={@user_project.name}
        info={@user_project.visibility}
        subtitle={@user_project.author}
        image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg")}
      >
        <CardButtons.render
          buttons={[
            {
              :edit,
              path: Routes.project_form_path(@socket, :edit, @user_project.id),
              label: "Edit",
              type: :link
            },
            {
              :delete,
              phx_value_ref: @user_project.id,
              label: "Delete",
              confirm_message: "Do you really want to delete this project? This action cannot be reverted."
            }
          ]}
        />
      </IndexCard.render>
    """
  end

  defp render_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_show_path(@socket, :show, @user_project.id)}
        title={@user_project.name}
        info={@user_project.visibility}
        subtitle={@user_project.author}
        image_source={@user_project.primary_asset.thumbnail_image}
      >
        <CardButtons.render
          buttons={[
            {
              :edit,
              path: Routes.project_form_path(@socket, :edit, @user_project.id),
              label: "Edit",
              type: :link
            },
            {
              :delete,
              phx_value_ref: @user_project.id,
              label: "Delete",
              confirm_message: "Do you really want to delete this project? This action cannot be reverted.",
            }
          ]}
        />
      </IndexCard.render>
    """
  end

  defp render_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_show_path(@socket, :show, @user_project.id)}
        title={@user_project.name}
        info={@user_project.visibility}
        subtitle={@user_project.author}
        image_source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg")}
      >
        <CardButtons.render
          buttons={[
            {
              :edit,
              path: Routes.project_form_path(@socket, :edit, @user_project.id),
              label: "Edit",
              type: :link
            },
            {
              :delete,
              phx_value_ref: @user_project.id,
              label: "Delete",
              confirm_message: "Do you really want to delete this project? This action cannot be reverted."
            }
          ]}
        />
      </IndexCard.render>
    """
  end
end

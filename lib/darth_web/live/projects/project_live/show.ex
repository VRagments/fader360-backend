defmodule DarthWeb.Projects.ProjectLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Controller.ProjectScene
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.AssetLease, as: AssetLeaseStruct
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct
  alias Darth.Controller.{Project, Asset, User, ProjectScene}
  alias Darth.Model.Project, as: ProjectStruct

  alias DarthWeb.Components.{
    ShowImage,
    Header,
    Stat,
    StatSelectField,
    Pagination,
    EmptyState,
    IndexCard,
    StatLinkButton,
    HeaderButtons,
    CardButtons,
    ShowDefault
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "project_scenes") do
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
        Logger.error("Error message: User not found in Database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"project_id" => project_id} = params, _url, socket) do
    select_options = Ecto.Enum.mappings(ProjectStruct, :visibility)

    project_scenes_query =
      ProjectSceneStruct
      |> where([ps], ps.user_id == ^socket.assigns.current_user.id and ps.project_id == ^project_id)

    with {:ok, project} <- Project.read(project_id, true),
         true <- project.user_id == socket.assigns.current_user.id,
         %{query_page: current_page, total_pages: total_pages, entries: project_scenes} <-
           ProjectScene.query(params, project_scenes_query, true) do
      project_scenes_map = Map.new(project_scenes, fn ps -> {ps.id, ps} end)
      project_scenes_list = ProjectScene.get_sorted_project_scenes_list(project_scenes_map)
      map_with_all_links = map_with_all_links(socket, total_pages, project)

      {:noreply,
       socket
       |> assign(
         project: project,
         select_options: select_options,
         project_scenes_map: project_scenes_map,
         project_scenes_list: project_scenes_list,
         total_pages: total_pages,
         current_page: current_page,
         changeset: ProjectStruct.changeset(project),
         map_with_all_links: map_with_all_links
       )}
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching project scenes: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to project scenes")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message: Database error while fetching user project: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch project")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      false ->
        Logger.error(
          "Error message: Database error while fetching user project: Current user don't have access to this project"
        )

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this project")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      err ->
        Logger.error("Error message: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

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
  def handle_event("delete", %{"ref" => project_scene_id}, socket) do
    socket =
      case ProjectScene.delete(project_scene_id) do
        :ok ->
          socket
          |> put_flash(:info, "Project scene deleted successfully")
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

        _ ->
          socket
          |> put_flash(:info, "Unable to delete project scene")
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_deleted, project}, socket) do
    socket =
      if socket.assigns.project.id == project.id do
        socket
        |> put_flash(:info, "Project deleted successfully")
        |> push_navigate(to: Routes.project_index_path(socket, :index))
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
        |> push_patch(to: Routes.project_show_path(socket, :show, project.id))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_scene_created, _project_scene}, socket) do
    get_updated_project_scene_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_scene_deleted, _project_scene}, socket) do
    get_updated_project_scene_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_scene_updated, project_scene}, socket) do
    project_scenes_map = Map.put(socket.assigns.project_scenes_map, project_scene.id, project_scene)
    project_scenes_list = ProjectScene.get_sorted_project_scenes_list(project_scenes_map)

    socket =
      socket
      |> assign(project_scenes_list: project_scenes_list, project_scenes_map: project_scenes_map)
      |> put_flash(:info, "Project scene updated")
      |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_project_scene_list(socket) do
    project_scenes_query =
      ProjectSceneStruct
      |> where([ps], ps.user_id == ^socket.assigns.current_user.id and ps.project_id == ^socket.assigns.project.id)

    socket =
      with %{entries: project_scenes} <- ProjectScene.query(%{}, project_scenes_query, true) do
        project_scenes_map = Map.new(project_scenes, fn ps -> {ps.id, ps} end)
        project_scenes_list = ProjectScene.get_sorted_project_scenes_list(project_scenes_map)

        socket
        |> assign(
          project_scenes_map: project_scenes_map,
          project_scenes_list: project_scenes_list
        )
      else
        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching project scenes: #{inspect(query_error)}")

          socket
          |> put_flash(:error, "Unable to project scenes")
          |> push_navigate(to: Routes.project_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  defp map_with_all_links(socket, total_pages, project) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.project_show_path(socket, :show, project.id, page: page)}
    end)
  end

  defp render_media_display(assigns) do
    with primary_asset_lease = %AssetLeaseStruct{} <- assigns.project.primary_asset_lease,
         normalised_media_type = Asset.normalized_media_type(primary_asset_lease.asset.media_type),
         true <- normalised_media_type == :audio do
      ~H"""
        <ShowImage.render source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}/>
      """
    else
      nil ->
        ~H"""
          <ShowDefault.render source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg" )}/>
        """

      false ->
        ~H"""
          <ShowImage.render source={@project.primary_asset.thumbnail_image}/>
        """
    end
  end

  defp render_project_stats(assigns) do
    ~H"""
      <Stat.render
        title="Author"
        value={@project.author}
      />
      <StatSelectField.render
        title="Visibility"
        form_chnage_name="update_visibility"
        input_name={:visibility}
        select_options={@select_options}
        changeset={@changeset}
      />
      <Stat.render
        title="Last Updated at"
        value={NaiveDateTime.to_date(@project.updated_at)}
      />
      <StatLinkButton.render
        action={:launch}
        level= {:primary}
        path={DarthWeb.Endpoint.url()<>Application.fetch_env!(:darth, :editor_url)
          <> "?project_id=#{@project.id}"}
        label={"Open in Editor"}
        type={:link}
      />
    """
  end

  defp render_scene_with_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_scene_show_path(@socket, :show, @user_project.id, @project_scene.id)}
        title={@project_scene.name}
        info={get_info(@project_scene.navigatable)}
        subtitle={@project_scene.duration <> " Sec"}
        image_source={@project_scene.primary_asset.thumbnail_image}
      >
        <CardButtons.render
          buttons={[
            {
              :edit,
              path: Routes.project_form_scenes_path(@socket, :edit, @user_project.id, @project_scene.id),
              label: "Edit"
            },
            {
              :delete,
              phx_value_ref: @project_scene.id,
              label: "Delete",
              confirm_message: "Do you really want to delete this project scene? This action cannot be reverted."
            }
          ]}
        />
      </IndexCard.render>
    """
  end

  defp render_scene_with_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_scene_show_path(@socket, :show, @user_project.id, @project_scene.id)}
        title={@project_scene.name}
        info={get_info(@project_scene.navigatable)}
        subtitle={@project_scene.duration <> " Sec"}
        image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg")}
      >
        <CardButtons.render
          buttons={[
            {
              :edit,
              path: Routes.project_form_scenes_path(@socket, :edit, @user_project.id, @project_scene.id),
              label: "Edit",
              type: :link
            },
            {
              :delete,
              phx_value_ref: @project_scene.id,
              label: "Delete",
              confirm_message: "Do you really want to delete this project scene? This action cannot be reverted."
            }
          ]}
        />
      </IndexCard.render>
    """
  end

  defp render_scene_card(assigns) do
    if ProjectScene.has_primary_asset_lease?(assigns.project_scene) do
      render_scene_with_image_card(assigns)
    else
      render_scene_with_default_card(assigns)
    end
  end

  defp get_info(navigatable) do
    case navigatable do
      true -> "Navigatable"
      false -> "Not Navigatable"
    end
  end
end

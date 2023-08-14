defmodule DarthWeb.Projects.ProjectLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.MvApiClient
  alias Darth.Controller.ProjectScene
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.AssetLease, as: AssetLeaseStruct
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct
  alias Darth.Controller.{Project, Asset, User, ProjectScene}
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.QrCodeGenerator
  alias DarthWeb.SaveFile

  alias DarthWeb.Components.{
    ShowImage,
    Header,
    Stat,
    StatSelectField,
    Pagination,
    EmptyState,
    IndexCard,
    StatButton,
    HeaderButtons,
    CardButtons,
    ShowDefault,
    ShowModel
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "project_scenes") do
      {:ok,
       socket
       |> assign(current_user: user)
       |> assign(mv_token: mv_token)}
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
         :ok <- Project.project_publish_status(project.published?),
         %{query_page: current_page, total_pages: total_pages, entries: project_scenes} <-
           ProjectScene.query(params, project_scenes_query, true) do
      project_scenes_map = Map.new(project_scenes, fn ps -> {ps.id, ps} end)
      project_scenes_list = ProjectScene.get_sorted_project_scenes_list(project_scenes_map)
      map_with_all_links = map_with_all_links(socket, total_pages, project)
      base_url = Path.join([DarthWeb.Endpoint.url(), DarthWeb.Endpoint.path("/")])
      editor_url = Application.fetch_env!(:darth, :editor_url)

      header_buttons = header_buttons(Project.is_mv_project?(project.mv_project_id), project.id, socket)

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
         map_with_all_links: map_with_all_links,
         header_buttons: header_buttons,
         base_url: base_url,
         editor_url: editor_url
       )}
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching project scenes: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to project scenes")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      {:error, :project_published} ->
        Logger.error("Error message: Cannot edit or view the project as it is already published to MediaVerse")

        socket =
          socket
          |> put_flash(:error, "Project already published to MediaVerse")
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
  def handle_event("upload_to_mediverse", _, socket) do
    project_scenes_list = socket.assigns.project_scenes_list
    project = socket.assigns.project
    now = Project.sanitized_current_date_time()
    project_data_filename = project.name <> "_fader_result_#{now}.png"
    published_project_name = project.name <> "_published_#{now}"
    mv_node = socket.assigns.current_user.mv_node
    mv_token = socket.assigns.mv_token
    published_project_base_path = Project.published_project_base_path(project)
    current_user = socket.assigns.current_user

    socket =
      with true <- Project.project_contain_scenes_and_scene_order_list?(project, project_scenes_list),
           {:ok, new_project} <-
             deep_copy_project_and_scenes_to_publish(project, published_project_name, current_user),
           {:ok, project_data_file_path} <-
             Project.create_project_result_file_path(published_project_base_path, project_data_filename),
           {:ok, encoded_project_data} <- Project.build_project_hash_to_publish(new_project.id),
           external_url = Project.generate_player_url(new_project.id) <> "&project_hash=#{encoded_project_data}",
           qr_code_png = QrCodeGenerator.generate_project_result_qr_code(external_url),
           :ok <- SaveFile.write_to_file(project_data_file_path, qr_code_png),
           asset_params = %{
             mv_node: mv_node,
             mv_token: mv_token,
             data_file_path: Path.join([published_project_base_path, project_data_filename]),
             description: project_data_filename,
             external_url: external_url
           },
           {:ok, %{"key" => mv_asset_key}} <- MvApiClient.upload_asset_to_mediaverse(asset_params),
           :ok <- MvApiClient.update_project(project.mv_project_id, mv_asset_key, mv_node, mv_token) do
        socket
        |> put_flash(:info, "Successfully pushed project result to MediaVerse")
        |> push_navigate(to: Routes.mv_project_published_projects_path(socket, :index))
      else
        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(
            :error,
            "Error while uploading project result file to MediaVerse: #{inspect(reason)}"
          )
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

        # Custom error message from MediaVerse
        {:ok, %{"message" => message}} ->
          Logger.error(inspect(message))

          socket
          |> put_flash(
            :error,
            "Error while pushing project result to MediaVerse: #{inspect(message)}"
          )
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

        {:ok, %{status_code: _, body: body}} ->
          decoded_body = Jason.decode(body)

          Logger.error(inspect(decoded_body))

          socket
          |> put_flash(
            :error,
            "Error while pushing project result to MediaVerse: #{inspect(decoded_body)}"
          )
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

        {:error, %Jason.DecodeError{} = reason} ->
          Logger.error("Jason Decode Error while pushing project result to MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(
            :error,
            "Error while pushing project result to MediaVerse: #{inspect(reason)}"
          )
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

        {:error, reason} ->
          Logger.error("Error while pushing project result to MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(
            :error,
            "Error while pushing project result to MediaVerse: #{inspect(reason)}"
          )
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

        false ->
          Logger.error(
            "Error while pushing project result to MediaVerse: Project does not contain valid Fader story"
          )

          socket
          |> put_flash(
            :error,
            "Error while pushing project result to MediaVerse: Project does not contain valid Fader story"
          )
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("create_template", _, socket) do
    project = socket.assigns.project
    now = Project.sanitized_current_date_time()
    new_project_name = project.name <> "_template_#{now}"
    current_user = socket.assigns.current_user
    project_scenes_list = socket.assigns.project_scenes_list

    socket =
      with true <- Project.project_contain_scenes_and_scene_order_list?(project, project_scenes_list),
           {:ok, _new_project} <- deep_copy_project_and_scenes_to_template(project, new_project_name, current_user) do
        socket
        |> put_flash(:info, "Successfully created a project template")
        |> push_navigate(to: Routes.template_index_path(socket, :index))
      else
        {:error, reason} ->
          Logger.error("Error while creating a project template: #{inspect(reason)}")

          socket
          |> put_flash(
            :error,
            "Error while creating a project template: #{inspect(reason)}"
          )
          |> push_patch(to: Routes.project_show_path(socket, :show, socket.assigns.project.id))

        false ->
          Logger.error("Error creating project template: Project does not contain valid Fader story")

          socket
          |> put_flash(
            :error,
            "Error creating project template: Project does not contain valid Fader story"
          )
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

  defp deep_copy_project_and_scenes_to_publish(project, new_project_name, user) do
    with {:ok, new_project} <- Project.duplicate_to_publish(project, new_project_name),
         {:ok, new_project} <- ProjectScene.dublicate(project, new_project, user) do
      {:ok, new_project}
    else
      err ->
        Logger.error("Error while dublicating project to publish: #{inspect(err)}")
        err
    end
  end

  defp deep_copy_project_and_scenes_to_template(project, new_project_name, user) do
    with {:ok, new_project} <- Project.duplicate_to_template(project, new_project_name),
         {:ok, new_project} <- ProjectScene.dublicate(project, new_project, user) do
      {:ok, new_project}
    else
      err ->
        Logger.error("Error while dublicating project to publish: #{inspect(err)}")
        err
    end
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
    case assigns.project.primary_asset_lease do
      primary_asset_lease = %AssetLeaseStruct{} ->
        normalised_media_type = Asset.normalized_media_type(primary_asset_lease.asset.media_type)
        render_project_display(assigns, normalised_media_type)

      nil ->
        ~H"""
          <ShowDefault.render source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg" )}/>
        """
    end
  end

  defp render_project_display(assigns, normalised_media_type) do
    case normalised_media_type do
      :audio ->
        ~H"""
          <ShowImage.render source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}/>
        """

      :image ->
        ~H"""
          <ShowImage.render source={@project.primary_asset.thumbnail_image}/>
        """

      :video ->
        ~H"""
          <ShowImage.render source={@project.primary_asset.thumbnail_image}/>
        """

      :model ->
        ~H"""
          <ShowModel.render source={@project.primary_asset.static_url}/>
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
      <StatButton.render
        action={:launch}
        level= {:primary}
        path={Path.join([@base_url, @editor_url]) <> "?project_id=#{@project.id}"}
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

  defp render_scene_with_model_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_scene_show_path(@socket, :show, @user_project.id, @project_scene.id)}
        title={@project_scene.name}
        info={get_info(@project_scene.navigatable)}
        subtitle={@project_scene.duration <> " Sec"}
        model_source={@project_scene.primary_asset.static_url}
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
      render_scene_with_primary_asset(assigns)
    else
      render_scene_with_default_card(assigns)
    end
  end

  defp render_scene_with_primary_asset(assigns) do
    normalised_media_type = Asset.normalized_media_type(assigns.project_scene.primary_asset.media_type)

    case normalised_media_type do
      :video -> render_scene_with_image_card(assigns)
      :image -> render_scene_with_image_card(assigns)
      :model -> render_scene_with_model_card(assigns)
    end
  end

  defp get_info(navigatable) do
    case navigatable do
      true -> "Navigatable"
      false -> "Not Navigatable"
    end
  end

  defp header_buttons(true, project_id, socket) do
    [
      {
        :edit,
        level: :secondary,
        type: :link,
        path: Routes.project_form_path(socket, :edit, project_id),
        label: "Edit Project"
      },
      nil,
      {
        :manage,
        level: :secondary,
        type: :link,
        path: Routes.project_form_assets_path(socket, :index, project_id),
        label: "Manage Project Assets"
      },
      nil,
      {
        :upload_to_mediverse,
        level: :secondary,
        type: :click,
        label: "Publish to MediaVerse",
        confirm_message: "Avoid clicking this button multiple times.
                Send only valid and publishable project to MediaVerse"
      },
      nil,
      {
        :create_template,
        level: :secondary,
        type: :click,
        label: "Create Template",
        confirm_message: "Avoid clicking this button multiple times.
                Create templates only with the completed projects."
      },
      nil,
      {
        :back,
        level: :secondary, type: :link, path: Routes.project_index_path(socket, :index), label: "Back"
      }
    ]
  end

  defp header_buttons(false, project_id, socket) do
    [
      {
        :edit,
        level: :secondary,
        type: :link,
        path: Routes.project_form_path(socket, :edit, project_id),
        label: "Edit Project"
      },
      nil,
      {
        :manage,
        level: :secondary,
        type: :link,
        path: Routes.project_form_assets_path(socket, :index, project_id),
        label: "Manage Project Assets"
      },
      nil,
      {
        :create_template,
        level: :secondary,
        type: :click,
        label: "Create Template",
        confirm_message: "Avoid clicking this button multiple times.
                Create templates only with the completed projects."
      },
      nil,
      {
        :back,
        level: :secondary, type: :link, path: Routes.project_index_path(socket, :index), label: "Back"
      }
    ]
  end
end

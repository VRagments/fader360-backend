defmodule DarthWeb.Templates.TemplateLive.Show do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Controller.{Project, User, ProjectScene, Asset}
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct
  alias Darth.Model.AssetLease, as: AssetLeaseStruct

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
    ShowDefault,
    ShowModel
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
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
  def handle_params(%{"template_id" => template_id} = params, _url, socket) do
    select_options = Ecto.Enum.mappings(ProjectStruct, :visibility)

    tamplate_scenes_query =
      ProjectSceneStruct
      |> where([ps], ps.project_id == ^template_id)

    with {:ok, template} <- Project.read(template_id, true),
         true <- Project.is_template?(template),
         %{query_page: current_page, total_pages: total_pages, entries: template_scenes} <-
           ProjectScene.query(params, tamplate_scenes_query, true) do
      template_scenes_map = Map.new(template_scenes, fn ps -> {ps.id, ps} end)
      template_scenes_list = ProjectScene.get_sorted_project_scenes_list(template_scenes_map)
      map_with_all_links = map_with_all_links(socket, total_pages, template)
      base_url = Path.join([DarthWeb.Endpoint.url(), DarthWeb.Endpoint.path("/")])
      editor_url = Application.fetch_env!(:darth, :editor_url)

      header_buttons = header_buttons(template.id, socket)

      {:noreply,
       socket
       |> assign(
         template: template,
         select_options: select_options,
         template_scenes_map: template_scenes_map,
         template_scenes_list: template_scenes_list,
         total_pages: total_pages,
         current_page: current_page,
         changeset: ProjectStruct.changeset(template),
         map_with_all_links: map_with_all_links,
         header_buttons: header_buttons,
         base_url: base_url,
         editor_url: editor_url,
         editable?: template.user_id == socket.assigns.current_user.id
       )}
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching template scenes: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to template scenes")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      {:error, :project_published} ->
        Logger.error("Error message: Cannot edit or view the template as it is already published to MediaVerse")

        socket =
          socket
          |> put_flash(:error, "Project already published to MediaVerse")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error message: Database error while fetching user template: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch template")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      false ->
        Logger.error(
          "Error message: Database error while fetching user template: Current user don't have access to this template"
        )

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this template")
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
  def handle_event("update_visibility", %{"project" => template_params}, socket) do
    case Project.update(socket.assigns.template, template_params) do
      {:ok, _} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("download", %{"ref" => template_id}, socket) do
    current_user = socket.assigns.current_user

    socket =
      with {:ok, project_template} <- Project.read(template_id),
           {:ok, _new_project} <- create_project_and_scenes_from_template(project_template, current_user) do
        socket
        |> put_flash(:info, "Successfully created a project from tamplate")
        |> push_navigate(to: Routes.project_index_path(socket, :index))
      else
        {:error, reason} ->
          Logger.error("Error while creating a project from template: #{inspect(reason)}")

          socket
          |> put_flash(
            :error,
            "Error while creating a project from template: #{inspect(reason)}"
          )
          |> push_patch(to: Routes.template_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_deleted, template}, socket) do
    socket =
      if socket.assigns.template.id == template.id do
        socket
        |> put_flash(:info, "Project deleted successfully")
        |> push_navigate(to: Routes.template_index_path(socket, :index))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_updated, template}, socket) do
    socket =
      if socket.assigns.template.id == template.id do
        socket
        |> put_flash(:info, "Template updated")
        |> push_patch(to: Routes.template_show_path(socket, :show, template.id))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp map_with_all_links(socket, total_pages, template) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.project_show_path(socket, :show, template.id, page: page)}
    end)
  end

  defp header_buttons(template_id, socket) do
    [
      {
        :download,
        level: :primary, type: :click, phx_value_ref: template_id, label: "Use"
      },
      nil,
      {
        :back,
        level: :secondary, type: :link, path: Routes.template_index_path(socket, :index), label: "Back"
      }
    ]
  end

  defp render_media_display(assigns) do
    case assigns.template.primary_asset_lease do
      primary_asset_lease = %AssetLeaseStruct{} ->
        normalised_media_type = Asset.normalized_media_type(primary_asset_lease.asset.media_type)
        render_template_display(assigns, normalised_media_type)

      nil ->
        ~H"""
          <ShowDefault.render source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg" )}/>
        """
    end
  end

  defp render_template_display(assigns, normalised_media_type) do
    case normalised_media_type do
      :audio ->
        ~H"""
          <ShowImage.render source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}/>
        """

      :image ->
        ~H"""
          <ShowImage.render source={@template.primary_asset.thumbnail_image}/>
        """

      :video ->
        ~H"""
          <ShowImage.render source={@template.primary_asset.thumbnail_image}/>
        """

      :model ->
        ~H"""
          <ShowModel.render source={@template.primary_asset.static_url}/>
        """
    end
  end

  defp render_template_stats(%{editable?: false} = assigns) do
    ~H"""
      <Stat.render
        title="Author"
        value={@template.author}
      />
      <Stat.render
        title="Visibility"
        value={@template.visibility}
      />
      <Stat.render
        title="Last Updated at"
        value={NaiveDateTime.to_date(@template.updated_at)}
      />
      <StatButton.render
        action={:launch}
        level= {:secondary}
        path={Project.generate_player_url(@template.id)}
        label={"Open in Player"}
        type={:link}
      />
    """
  end

  defp render_template_stats(assigns) do
    ~H"""
      <Stat.render
        title="Author"
        value={@template.author}
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
        value={NaiveDateTime.to_date(@template.updated_at)}
      />
      <StatButton.render
        action={:launch}
        level= {:secondary}
        path={Project.generate_player_url(@template.id)}
        label={"Open in Player"}
        type={:link}
      />
    """
  end

  defp render_scene_with_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={}
        title={@template_scene.name}
        info={get_info(@template_scene.navigatable)}
        subtitle={@template_scene.duration <> " Sec"}
        image_source={@template_scene.primary_asset.thumbnail_image}
      >
        <% %>
      </IndexCard.render>
    """
  end

  defp render_scene_with_model_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={}
        title={@template_scene.name}
        info={get_info(@template_scene.navigatable)}
        subtitle={@template_scene.duration <> " Sec"}
        model_source={@template_scene.primary_asset.static_url}
      >
        <% %>
      </IndexCard.render>
    """
  end

  defp render_scene_with_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={}
        title={@template_scene.name}
        info={get_info(@template_scene.navigatable)}
        subtitle={@template_scene.duration <> " Sec"}
        image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg")}
      >
        <% %>
      </IndexCard.render>
    """
  end

  defp render_scene_card(assigns) do
    if ProjectScene.has_primary_asset_lease?(assigns.template_scene) do
      render_scene_with_primary_asset(assigns)
    else
      render_scene_with_default_card(assigns)
    end
  end

  defp render_scene_with_primary_asset(assigns) do
    normalised_media_type = Asset.normalized_media_type(assigns.template_scene.primary_asset.media_type)

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

  defp create_project_and_scenes_from_template(project, user) do
    with {:ok, new_project} <- Project.create_project_from_template(project, user),
         {:ok, new_project} <- ProjectScene.dublicate_from_template(project, new_project, user) do
      {:ok, new_project}
    else
      err ->
        Logger.error("Error while dublicating project to publish: #{inspect(err)}")
        err
    end
  end
end

defmodule DarthWeb.Templates.TemplateLive.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Controller.User
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.Project
  alias Darth.Controller.ProjectScene
  alias Darth.Controller.Asset

  alias DarthWeb.Components.{
    IndexCard,
    Header,
    Pagination,
    EmptyState,
    CardButtons
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
  def handle_params(params, _url, socket) do
    query =
      ProjectStruct
      |> where(
        [t],
        (t.visibility == :discoverable or t.user_id == ^socket.assigns.current_user.id) and t.template? == true
      )

    case Project.query(params, query, true) do
      %{query_page: current_page, total_pages: total_pages, entries: user_templates} ->
        user_templates_map = Map.new(user_templates, fn up -> {up.id, up} end)
        user_templates_list = Project.get_sorted_user_project_list(user_templates_map)
        map_with_all_links = map_with_all_links(socket, total_pages)

        socket =
          socket
          |> assign(
            current_page: current_page,
            total_pages: total_pages,
            user_templates_list: user_templates_list,
            user_templates_map: user_templates_map,
            map_with_all_links: map_with_all_links
          )

        {:noreply, socket}

      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching user templates: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch templates")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}
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
  def handle_event("delete", %{"ref" => template_id}, socket) do
    socket =
      case Project.delete(template_id) do
        :ok ->
          socket
          |> put_flash(:info, "Template deleted successfully")
          |> push_patch(to: Routes.template_index_path(socket, :index))

        err ->
          socket
          |> put_flash(:info, "Unable to delete template: #{inspect(err)}")
          |> push_patch(to: Routes.template_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_created, _}, socket) do
    get_updated_template_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_deleted, _}, socket) do
    get_updated_template_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_updated, template}, socket) do
    user_temaplates_map = Map.put(socket.assigns.user_temaplates_map, template.id, template)
    user_temaplates_list = Project.get_sorted_user_project_list(user_temaplates_map)

    socket =
      socket
      |> assign(
        user_temaplates_list: user_temaplates_list,
        user_temaplates_map: user_temaplates_map
      )
      |> put_flash(:info, "Template updated")
      |> push_patch(to: Routes.template_index_path(socket, :index))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_template_list(socket) do
    query =
      ProjectStruct
      |> where(
        [t],
        (t.visibility == :discoverable or t.user_id == ^socket.assigns.current_user.id) and t.template? == true
      )

    socket =
      with %{entries: user_templates} <- Project.query(%{}, query, true),
           user_temaplates_map = Map.new(user_templates, fn ut -> {ut.id, ut} end),
           user_temaplates_list = Project.get_sorted_user_project_list(user_temaplates_map) do
        socket
        |> assign(
          user_temaplates_list: user_temaplates_list,
          user_temaplates_map: user_temaplates_map
        )
      else
        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

          socket
          |> put_flash(:error, "Unable to fetch Temaplates")
          |> push_patch(to: Routes.template_index_path(socket, :index))

        err ->
          Logger.error("Error message: #{inspect(err)}")

          socket
          |> put_flash(:error, "Unable to fetch templates")
          |> push_patch(to: Routes.template_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  defp map_with_all_links(socket, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.template_index_path(socket, :index, page: page)}
    end)
  end

  defp render_template_card(assigns) do
    if Project.has_primary_asset_lease?(assigns.user_template) do
      render_template_media_card(assigns)
    else
      render_default_card(assigns)
    end
  end

  defp render_template_media_card(assigns) do
    media_type = Asset.normalized_media_type(assigns.user_template.primary_asset.media_type)

    case media_type do
      :audio -> render_audio_card(assigns)
      :video -> render_image_card(assigns)
      :image -> render_image_card(assigns)
      :model -> render_model_card(assigns)
    end
  end

  defp render_audio_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.template_show_path(@socket, :show, @user_template.id)}
        title={@user_template.name}
        info={@user_template.visibility}
        subtitle={@user_template.author}
        image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg")}
      >
        <CardButtons.render
          buttons={render_card_buttons(@user_template, @current_user)}
        />
      </IndexCard.render>
    """
  end

  defp render_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.template_show_path(@socket, :show, @user_template.id)}
        title={@user_template.name}
        info={@user_template.visibility}
        subtitle={@user_template.author}
        image_source={@user_template.primary_asset.thumbnail_image}
      >
        <CardButtons.render
          buttons={render_card_buttons(@user_template, @current_user)}
        />
      </IndexCard.render>
    """
  end

  defp render_model_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.template_show_path(@socket, :show, @user_template.id)}
        title={@user_template.name}
        info={@user_template.visibility}
        subtitle={@user_template.author}
        model_source={@user_template.primary_asset.static_url}
      >
        <CardButtons.render
          buttons={render_card_buttons(@user_template, @current_user)}
        />
      </IndexCard.render>
    """
  end

  defp render_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.template_show_path(@socket, :show, @user_template.id)}
        title={@user_template.name}
        info={@user_template.visibility}
        subtitle={@user_template.author}
        image_source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg")}
      >
        <CardButtons.render
          buttons={render_card_buttons(@user_template, @current_user)}
        />
      </IndexCard.render>
    """
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

  defp render_card_buttons(template, current_user) do
    case template.user_id == current_user.id do
      true ->
        [
          {
            :download,
            phx_value_ref: template.id, label: "Use"
          },
          {
            :delete,
            phx_value_ref: template.id,
            label: "Delete",
            confirm_message: "Do you really want to delete this project? This action cannot be reverted."
          }
        ]

      false ->
        [
          {
            :download,
            phx_value_ref: template.id, label: "Use"
          }
        ]
    end
  end
end

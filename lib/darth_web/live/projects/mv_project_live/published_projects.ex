defmodule DarthWeb.Projects.MvProjectLive.PublishedProjects do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.Project

  alias DarthWeb.Components.{
    IndexCard,
    Header,
    Pagination,
    EmptyState
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
      {:ok, socket |> assign(current_user: user)}
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
      |> where([p], p.user_id == ^socket.assigns.current_user.id and p.published? == true)

    case Project.query(params, query, true) do
      %{query_page: current_page, total_pages: total_pages, entries: user_projects} ->
        user_projects_map = Map.new(user_projects, fn up -> {up.id, up} end)
        user_projects_list = Project.get_sorted_user_project_list(user_projects_map)
        map_with_all_links = map_with_all_links(socket, total_pages)

        socket =
          socket
          |> assign(
            current_page: current_page,
            total_pages: total_pages,
            user_projects_list: user_projects_list,
            user_projects_map: user_projects_map,
            map_with_all_links: map_with_all_links
          )

        {:noreply, socket}

      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch projects")
          |> push_navigate(to: Routes.mv_project_published_projects_path(socket, :index))

        {:noreply, socket}
    end
  end

  defp map_with_all_links(socket, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.mv_project_published_projects_path(socket, :index, page: page)}
    end)
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
      :model -> render_model_card(assigns)
    end
  end

  defp render_audio_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Project.generate_player_url(@user_project.id)}
        title={@user_project.name}
        info={@user_project.visibility}
        subtitle={@user_project.author}
        image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg")}
      >
        <% %>
      </IndexCard.render>
    """
  end

  defp render_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Project.generate_player_url(@user_project.id)}
        title={@user_project.name}
        info={@user_project.visibility}
        subtitle={@user_project.author}
        image_source={@user_project.primary_asset.thumbnail_image}
      >
        <% %>
      </IndexCard.render>
    """
  end

  defp render_model_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Project.generate_player_url(@user_project.id)}
        title={@user_project.name}
        info={@user_project.visibility}
        subtitle={@user_project.author}
        model_source={@user_project.primary_asset.static_url}
      >
        <% %>
      </IndexCard.render>
    """
  end

  defp render_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Project.generate_player_url(@user_project.id)}
        title={@user_project.name}
        info={@user_project.visibility}
        subtitle={@user_project.author}
        image_source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg")}
      >
        <% %>
      </IndexCard.render>
    """
  end
end

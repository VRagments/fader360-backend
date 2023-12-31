defmodule DarthWeb.Projects.ProjectLive.SceneShow do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.{User, Project, ProjectScene, Asset, AssetLease}

  alias DarthWeb.Components.{
    Header,
    ShowCard,
    Icons,
    ShowImage,
    Stat,
    CardButtons,
    HeaderButtons,
    ShowDefault,
    ShowModel
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
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"project_id" => project_id, "project_scene_id" => project_scene_id}, _url, socket) do
    with {:ok, project} <- fetch_project(socket, project_id),
         {:ok, project_scene} <- fetch_project_scene(socket, project_scene_id, project_id),
         {:ok, project_asset_leases} <- Project.fetch_project_asset_leases(project) do
      filtered_project_asset_leases = filter_video_and_image_asset_leases(project_asset_leases)
      project_asset_leases_map = Map.new(filtered_project_asset_leases, fn pal -> {pal.id, pal} end)
      project_asset_leases_list = Asset.get_sorted_asset_lease_list(project_asset_leases_map)

      {:noreply,
       socket
       |> assign(
         project: project,
         project_scene: project_scene,
         project_asset_leases_map: project_asset_leases_map,
         project_asset_leases_list: project_asset_leases_list
       )}
    else
      {:error, reason} ->
        Logger.error("Error message: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Error: #{inspect(reason)}")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("assign", %{"ref" => asset_lease_id}, socket) do
    socket =
      with {:ok, project_scene} <-
             ProjectScene.update(socket.assigns.project_scene, %{primary_asset_lease_id: asset_lease_id}),
           {:ok, project_scene} <- ProjectScene.read(project_scene.id) do
        socket
        |> assign(project_scene: project_scene)
        |> put_flash(:info, "Asset assigned to project scene")
        |> push_patch(
          to:
            Routes.project_scene_show_path(
              socket,
              :show,
              socket.assigns.project.id,
              socket.assigns.project_scene.id
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease to project scene:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to assign asset to the project scene")
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("unassign", %{"ref" => _asset_lease_id}, socket) do
    socket =
      with {:ok, project_scene} <-
             ProjectScene.update(socket.assigns.project_scene, %{primary_asset_lease_id: nil}),
           {:ok, project_scene} <- ProjectScene.read(project_scene.id) do
        socket
        |> assign(project_scene: project_scene)
        |> put_flash(:info, "Asset assigned to project scene")
        |> push_patch(
          to:
            Routes.project_scene_show_path(
              socket,
              :show,
              socket.assigns.project.id,
              socket.assigns.project_scene.id
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error message:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to remove asset from the project")
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
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
  def handle_info({:project_deleted, _project}, socket) do
    socket
    |> put_flash(:error, "Project deleted")
    |> push_navigate(to: Routes.project_index_path(socket, :index))
  end

  @impl Phoenix.LiveView
  def handle_info({:project_updated, project}, socket) do
    socket =
      socket
      |> assign(project: project)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_scene_created, project_scene}, socket) do
    socket =
      socket
      |> assign(project_scene: project_scene)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_scene_deleted, project_scene}, socket) do
    socket =
      socket
      |> assign(project_scene: project_scene)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:project_scene_updated, project_scene}, socket) do
    socket =
      socket
      |> assign(project_scene: project_scene)
      |> put_flash(:info, "Project scene updated")
      |> push_patch(to: Routes.project_scene_show_path(socket, :show, socket.assigns.project.id, project_scene.id))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp fetch_project(socket, project_id) do
    with {:ok, project} <- Project.read(project_id, true),
         true <- project.user_id == socket.assigns.current_user.id do
      {:ok, project}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, "Current user is not the owner of the project"}
    end
  end

  defp fetch_project_scene(socket, project_scene_id, project_id) do
    with {:ok, project_scene} <- ProjectScene.read(project_scene_id, true),
         true <- project_scene.user_id == socket.assigns.current_user.id,
         true <- project_scene.project_id == project_id do
      {:ok, project_scene}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, "Project scene does not belong to the project or current user"}
    end
  end

  defp get_updated_asset_list(socket) do
    socket =
      case Project.fetch_project_asset_leases(socket.assigns.project) do
        {:ok, project_asset_leases} ->
          filtered_project_asset_leases = filter_video_and_image_asset_leases(project_asset_leases)
          project_asset_leases_map = Map.new(filtered_project_asset_leases, fn pal -> {pal.id, pal} end)
          project_asset_leases_list = Asset.get_sorted_asset_lease_list(project_asset_leases_map)

          socket
          |> assign(
            project_asset_leases_map: project_asset_leases_map,
            project_asset_leases_list: project_asset_leases_list
          )

        {:error, reason} ->
          Logger.error("Error message: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Error: #{inspect(reason)}")
          |> push_navigate(to: Routes.project_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  defp filter_video_and_image_asset_leases(project_asset_leases) do
    Enum.filter(project_asset_leases, fn project_asset_lease ->
      Asset.normalized_media_type(project_asset_lease.asset.media_type) != :audio and
        project_asset_lease.asset.status == "ready"
    end)
  end

  defp render_media_display(assigns) do
    if ProjectScene.has_primary_asset_lease?(assigns.project_scene) do
      normalised_media_type = Asset.normalized_media_type(assigns.project_scene.primary_asset.media_type)
      render_project_scene_display(assigns, normalised_media_type)
    else
      ~H"""
      <ShowDefault.render source={Routes.static_path(@socket, "/images/DefaultFileImage.svg")}/>
      """
    end
  end

  defp render_project_scene_display(assigns, normalized_media_type) do
    case normalized_media_type do
      :image ->
        ~H"""
          <ShowImage.render source={@project_scene.primary_asset.thumbnail_image}/>
        """

      :video ->
        ~H"""
          <ShowImage.render source={@project_scene.primary_asset.thumbnail_image}/>
        """

      :model ->
        ~H"""
          <ShowModel.render source={@project_scene.primary_asset.static_url}/>
        """
    end
  end

  defp render_scene_stats(assigns) do
    ~H"""
      <Stat.render title="Duration"
        value={@project_scene.duration}
        unit="Sec"
      />
      <Stat.render
        title="Navigatable?"
        value={@project_scene.navigatable}
      />
      <Stat.render
        title="Last Updated at"
        value={NaiveDateTime.to_date(@project_scene.updated_at)}
      />
    """
  end

  defp render_added_asset_card_with_one_button(assigns) do
    normalised_media_type = Asset.normalized_media_type(assigns.asset_lease.asset.media_type)

    case normalised_media_type do
      :image -> render_added_image_card(assigns)
      :video -> render_added_image_card(assigns)
      :model -> render_added_model_card(assigns)
    end
  end

  defp render_added_image_card(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        source={@asset_lease.asset.thumbnail_image}
        subtitle={@asset_lease.asset.media_type}
        status= "using as scene background"
      >
        <CardButtons.render
          buttons={[
            {
              :unassign,
              phx_value_ref: @asset_lease.id,
              label: "Remove"
            }
          ]}
        />
      </ShowCard.render>
    """
  end

  defp render_added_model_card(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        model_source={@asset_lease.asset.static_url}
        subtitle={@asset_lease.asset.media_type}
        status= "using as scene background"
      >
        <CardButtons.render
          buttons={[
            {
              :unassign,
              phx_value_ref: @asset_lease.id,
              label: "Remove"
            }
          ]}
        />
      </ShowCard.render>
    """
  end

  defp render_available_asset_card_with_one_button(assigns) do
    normalised_media_type = Asset.normalized_media_type(assigns.asset_lease.asset.media_type)

    case normalised_media_type do
      :image -> render_available_image_card(assigns)
      :video -> render_available_image_card(assigns)
      :model -> render_available_model_card(assigns)
    end
  end

  defp render_available_image_card(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        source={@asset_lease.asset.thumbnail_image}
        subtitle={@asset_lease.asset.media_type}
      >
        <CardButtons.render
          buttons={[
            {
              :assign,
              phx_value_ref: @asset_lease.id,
              label: "Make scene background"
            }
          ]}
        />
      </ShowCard.render>
    """
  end

  defp render_available_model_card(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        model_source={@asset_lease.asset.static_url}
        subtitle={@asset_lease.asset.media_type}
      >
        <CardButtons.render
          buttons={[
            {
              :assign,
              phx_value_ref: @asset_lease.id,
              label: "Add"
            }
          ]}
        />
      </ShowCard.render>
    """
  end
end

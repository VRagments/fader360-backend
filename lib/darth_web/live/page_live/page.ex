defmodule DarthWeb.PageLive.Page do
  use DarthWeb, :live_navbar_view
  require Logger
  import Ecto.Query
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.Project
  alias Darth.Controller.AssetLease
  alias DarthWeb.UploadProcessor

  alias DarthWeb.Components.{
    Activity,
    Header,
    IndexCard,
    HyperLink,
    HeaderButtons,
    UploadProgress,
    EmptyState
  }

  @impl Phoenix.LiveView
  @spec mount(any, map, any) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, %{"user_token" => user_token}, socket) do
    upload_file_size = Application.fetch_env!(:darth, :upload_file_size)

    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
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
  def handle_params(_params, _url, socket) do
    socket =
      with %{entries: asset_leases} <-
             AssetLease.query_by_user(socket.assigns.current_user.id, %{"size" => "5"}, false),
           query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id),
           %{entries: projects} <- Project.query(%{"size" => "5"}, query, true) do
        asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end)

        asset_leases_list =
          Asset.get_sorted_asset_lease_list(asset_leases_map)
          |> Enum.sort_by(& &1.updated_at, :desc)

        projects_map = Map.new(projects, fn up -> {up.id, up} end)

        projects_list =
          Project.get_sorted_user_project_list(projects_map)
          |> Enum.sort_by(& &1.updated_at, :desc)

        sorted_combined_entries =
          Enum.concat(asset_leases, projects)
          |> Enum.sort_by(& &1.updated_at, :desc)

        socket
        |> assign(
          sorted_combined_entries: sorted_combined_entries,
          asset_leases_map: asset_leases_map,
          asset_leases_list: asset_leases_list,
          projects_map: projects_map,
          projects_list: projects_list
        )
      else
        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching asset via asset leases: #{query_error}")

          socket
          |> put_flash(:error, "Unable to fetch assets")

        err ->
          Logger.error("Error message: Database error while fetching asset via asset leases: #{err}")

          socket
          |> put_flash(:error, "Unable to fetch assets")
      end

    {:noreply, socket}
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

        asset_leases_list =
          Asset.get_sorted_asset_lease_list(updated_asset_leases_map)
          |> Enum.sort_by(& &1.updated_at, :desc)

        socket
        |> assign(
          asset_leases_list: asset_leases_list,
          asset_leases_map: updated_asset_leases_map
        )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_created, _asset_lease}, socket) do
    get_updated_projects_and_assets(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_updated, _asset_lease}, socket) do
    get_updated_projects_and_assets(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, _asset_lease}, socket) do
    get_updated_projects_and_assets(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_created, _project}, socket) do
    get_updated_projects_and_assets(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_deleted, _project}, socket) do
    get_updated_projects_and_assets(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:project_updated, _project}, socket) do
    get_updated_projects_and_assets(socket)
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    user = socket.assigns.current_user

    socket =
      with :ok <- UploadProcessor.create_uploads_base_path(),
           {:ok, uploaded_file_path} <- UploadProcessor.get_uploaded_entries(socket, :media),
           {:ok, asset_details} <- UploadProcessor.get_asset_details(socket, uploaded_file_path),
           :ok <- UploadProcessor.check_for_uploaded_asset_media_type(asset_details),
           {:ok, asset_struct} <- Asset.create(asset_details),
           {:ok, asset_struct} <- Asset.init(asset_struct, asset_details),
           {:ok, _lease} <- AssetLease.create_for_user(asset_struct, user),
           :ok <- File.rm(uploaded_file_path) do
        socket
        |> put_flash(:info, "Uploaded Successfully")
        |> push_patch(to: Routes.page_page_path(socket, :index))
      else
        {:error, reason} ->
          Logger.error("Error while uploading the asset: #{inspect(reason)}")

          socket
          |> put_flash(:error, inspect(reason))
      end

    {:noreply, socket}
  end

  defp get_updated_projects_and_assets(socket) do
    socket =
      with %{entries: asset_leases} <-
             AssetLease.query_by_user(socket.assigns.current_user.id, %{"size" => "5"}, false),
           query = ProjectStruct |> where([p], p.user_id == ^socket.assigns.current_user.id),
           %{entries: projects} <- Project.query(%{"size" => "5"}, query, true) do
        asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end)

        asset_leases_list =
          Asset.get_sorted_asset_lease_list(asset_leases_map)
          |> Enum.sort_by(& &1.updated_at, :desc)

        projects_map = Map.new(projects, fn up -> {up.id, up} end)

        projects_list =
          Project.get_sorted_user_project_list(projects_map)
          |> Enum.sort_by(& &1.updated_at, :desc)

        sorted_combined_entries =
          Enum.concat(asset_leases, projects)
          |> Enum.sort_by(& &1.updated_at, :desc)
          |> Enum.slice(0..9)

        socket
        |> assign(
          sorted_combined_entries: sorted_combined_entries,
          asset_leases_map: asset_leases_map,
          asset_leases_list: asset_leases_list,
          projects_map: projects_map,
          projects_list: projects_list
        )
      else
        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching asset via asset leases: #{query_error}")

          socket
          |> put_flash(:error, "Unable to fetch assets")

        err ->
          Logger.error("Error message: Database error while fetching asset via asset leases: #{err}")

          socket
          |> put_flash(:error, "Unable to fetch assets")
      end

    {:noreply, socket}
  end

  defp render_asset_audio_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.asset_show_path(@socket, :show,@card.id)}
        title={@card.asset.name}
        info={@card.asset.status}
        subtitle={@card.asset.media_type}
        image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg")}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_asset_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.asset_show_path(@socket, :show,@card.id)}
        title={@card.asset.name}
        info={@card.asset.status}
        subtitle={@card.asset.media_type}
        image_source={@card.asset.thumbnail_image}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_asset_model_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.asset_show_path(@socket, :show,@card.id)}
        title={@card.asset.name}
        info={@card.asset.status}
        subtitle={@card.asset.media_type}
        model_source={@card.asset.static_url}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_asset_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.asset_show_path(@socket, :show,@card.id)}
        title={@card.asset.name}
        info={@card.asset.status}
        subtitle={@card.asset.media_type}
        image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg")}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_project_audio_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_show_path(@socket, :show, @card.id)}
        title={@card.name}
        info={@card.visibility}
        subtitle={@card.author}
        image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg")}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_project_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_show_path(@socket, :show, @card.id)}
        title={@card.name}
        info={@card.visibility}
        subtitle={@card.author}
        image_source={@card.primary_asset.thumbnail_image}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_project_model_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_show_path(@socket, :show, @card.id)}
        title={@card.name}
        info={@card.visibility}
        subtitle={@card.author}
        model_source={@card.primary_asset.static_url}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_project_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.project_show_path(@socket, :show, @card.id)}
        title={@card.name}
        info={@card.visibility}
        subtitle={@card.author}
        image_source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg")}
      >
      </IndexCard.render>
    """
  end

  defp get_asset_card(assigns) do
    normalised_media_type = Asset.normalized_media_type(assigns.card.asset.media_type)

    if Asset.is_asset_status_ready?(assigns.card.asset.status) do
      case normalised_media_type do
        :audio -> render_asset_audio_card(assigns)
        :image -> render_asset_image_card(assigns)
        :video -> render_asset_image_card(assigns)
        :model -> render_asset_model_card(assigns)
      end
    else
      render_asset_default_card(assigns)
    end
  end

  defp get_project_card(assigns) do
    if Project.has_primary_asset_lease?(assigns.card) do
      normalised_media_type = Asset.normalized_media_type(assigns.card.primary_asset.media_type)

      case normalised_media_type do
        :audio -> render_project_audio_card(assigns)
        :image -> render_project_image_card(assigns)
        :video -> render_project_image_card(assigns)
        :model -> render_project_model_card(assigns)
      end
    else
      render_project_default_card(assigns)
    end
  end

  defp render_card(assigns) do
    case assigns.card do
      %{author: _} ->
        get_project_card(assigns)

      %{asset: _} ->
        get_asset_card(assigns)

      nil ->
        ~H""
    end
  end
end

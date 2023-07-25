defmodule Darth.Controller.Project do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.Controller
  alias Darth.Model.ProjectScene, as: ProjectSceneStruct
  alias Darth.Model.Asset
  alias Darth.MvApiClient
  alias Darth.AssetProcessor.Downloader

  def model_mod, do: Darth.Model.Project
  def default_query_sort_by, do: "updated_at"

  def default_select_fields do
    ~w(
      author
      data
      id
      inserted_at
      custom_colorscheme
      custom_font
      custom_icon_audio
      custom_icon_image
      custom_icon_video
      custom_logo
      custom_player_settings
      mv_project_id
      published?
      name
      primary_asset_lease_id
      updated_at
      user_id
      visibility
    )a
  end

  def default_preload_assocs do
    ~w(
      primary_asset
      primary_asset_lease
      project_categories
      user
    )a
  end

  def new(params) do
    params =
      if is_nil(params["name"]) or params["name"] == "" do
        name = "Story #{Faker.App.name()}"
        Map.put(params, "name", name)
      else
        params
      end

    params =
      if is_nil(params["data"]) or params["data"] == "" do
        Map.put(params, "data", %{})
      else
        params
      end

    params =
      if is_nil(params["published?"]) or params["published?"] == "" do
        Map.put(params, "published?", false)
      else
        params
      end

    params =
      if is_nil(params["visibility"]) or params["visibility"] == "" do
        Map.put_new(params, "visibility", :private)
      else
        params
      end

    Project.changeset(%Project{}, params)
  end

  def create(params) do
    with {:ok, p} <- params |> new() |> Repo.insert(),
         :ok <- broadcast("projects", {:project_created, p}) do
      read(p.id)
    end
  end

  def update({:error, _} = err, _), do: err
  def update({:ok, project}, params), do: update(project, params)

  def update(%Project{} = project, params) do
    cset = Project.changeset(project, params)

    case Repo.update(cset) do
      {:ok, project} = ok ->
        broadcast("projects", {:project_updated, project})
        ok

      err ->
        err
    end
  end

  def update(id, params), do: id |> read() |> update(params)

  def update_categories(%Project{} = p, target_category_ids) do
    new_categories = Controller.ProjectCategory.list_by_ids(target_category_ids)

    p
    |> Repo.preload(:project_categories)
    |> Project.changeset()
    |> Ecto.Changeset.put_assoc(:project_categories, new_categories)
    |> Repo.update()
  end

  def delete(%Project{} = a), do: a |> Project.delete_changeset() |> Repo.delete() |> delete_repo()
  def delete(nil), do: {:error, :not_found}
  def delete(id), do: Project |> Repo.get(id) |> delete

  def duplicate_to_publish(project, name) do
    params = %{
      "name" => name,
      "data" => project.data,
      "user_id" => project.user_id,
      "visibility" => :discoverable,
      "author" => project.author,
      "mv_project_id" => project.mv_project_id,
      "published?" => true
    }

    with {:ok, new_project} <- create(params),
         new_project <- Repo.preload(new_project, [:user]),
         project <- Repo.preload(project, [:primary_asset_lease, :asset_leases]),
         {:ok, new_project} <- copy_primary_asset_lease(new_project, project.primary_asset_lease),
         :ok <- copy_asset_leases(new_project, project.asset_leases) do
      read(new_project.id)
    end
  end

  def query_recommendations(%Project{id: id, user: user}, params \\ %{}) do
    custom_query =
      Project
      |> where([p], p.visibility == :discoverable)
      |> where([p], p.id != ^id)
      |> join(:inner, [p], u in assoc(p, :user), on: u.id == ^user.id)

    query(params, custom_query)
  end

  def has_primary_asset_lease?(project), do: not is_nil(project.primary_asset_lease_id)

  def unassign_primary_asset_lease(project, asset_lease) do
    with true <- project.primary_asset_lease_id == asset_lease.id,
         {:ok, project} <- update(project, %{primary_asset_lease_id: nil}) do
      {:ok, project}
    else
      false ->
        {:ok, project}

      _ ->
        {:error, "unable to update the primary asset"}
    end
  end

  def get_sorted_user_project_list(user_projects_map) do
    user_projects_map
    |> Map.values()
    |> Enum.sort_by(& &1.inserted_at)
  end

  def pre_load_asset_leases_and_assets_into_project(project) do
    Repo.preload(project, asset_leases: :asset)
  end

  def fetch_project_asset_leases(project) do
    case pre_load_asset_leases_and_assets_into_project(project) do
      pre_loaded_project = %Project{} ->
        {:ok, pre_loaded_project.asset_leases}

      error ->
        Logger.error("Error while preloading asset_lease of a project: #{inspect(error)}")
        {:error, "Error while fetching assets from this project"}
    end
  end

  def published_project_base_path(project) do
    path = Application.get_env(:darth, :project_static_base_path)
    app_path = Application.app_dir(:darth, path)
    Path.join(app_path, project.id)
  end

  def sanitized_current_date_time() do
    DateTime.utc_now()
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
    |> String.replace("-", "")
    |> String.replace(":", "")
    |> String.replace(" ", "-")
  end

  def generate_player_url(project_id) do
    Path.join([
      DarthWeb.Endpoint.url(),
      DarthWeb.Endpoint.path("/"),
      Application.fetch_env!(:darth, :player_url),
      "?project_id=#{project_id}"
    ])
  end

  def project_contain_scenes_and_scene_order_list?(project, project_scenes_list) do
    project_data = project.data
    project_scene_list_in_order = Map.get(project_data, "sceneOrder")
    !is_nil(project_scene_list_in_order) and !Enum.empty?(project_scenes_list)
  end

  def build_project_hash_to_publish(project_id) do
    project_scenes_query = ProjectSceneStruct |> where([ps], ps.project_id == ^project_id)

    with {:ok, project} <- read(project_id, true),
         %{entries: project_scenes} <- Controller.ProjectScene.query(%{}, project_scenes_query, true) do
      project_scenes_map = Map.new(project_scenes, fn ps -> {ps.id, ps} end)
      project_scenes_list = Controller.ProjectScene.get_sorted_project_scenes_list(project_scenes_map)

      binary_project_data =
        %{
          fader_project_name: project.name,
          fader_project_author: project.author,
          fader_project_data: project.data,
          fader_project_scenes_data: Enum.map(project_scenes_list, fn project_scene -> project_scene.data end),
          mediaverse_project_id: project.mv_project_id,
          mediaverse_assets: get_project_assets_mediaverse_ids(project)
        }
        |> :erlang.term_to_binary()

      encoded_data =
        :crypto.hash(:sha256, binary_project_data)
        |> Base.encode32()

      {:ok, encoded_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp delete_repo({:ok, project}) do
    broadcast("projects", {:project_deleted, project})
  end

  defp delete_repo(err), do: err

  defp copy_primary_asset_lease(project, nil), do: {:ok, project}

  defp copy_primary_asset_lease(project, lease) do
    with {:ok, _} <- Controller.AssetLease.assign_project(lease, project.user, project) do
      update(project, %{primary_asset_lease_id: lease.id})
    else
      err ->
        _ =
          Logger.warn(~s(Couldn't assign primary asset lease #{lease.id} to project #{project.id}: #{inspect(err)}))

        # this is not a critical error
        {:ok, project}
    end
  end

  defp copy_asset_leases(project, leases) do
    Enum.each(leases, fn lease ->
      case Controller.AssetLease.assign_project(lease, project.user, project) do
        {:ok, _} ->
          :ok

        {:error, err} ->
          Logger.warn(~s(Couldn't assign asset lease #{lease.id} to project #{project.id}: #{inspect(err)}))
      end
    end)
  end

  def load_virtual_field(model, "custom_colorscheme") do
    Controller.User.colorscheme(model.user)
  end

  def load_virtual_field(model, "custom_font") do
    Controller.User.font(model.user)["url"]
  end

  def load_virtual_field(model, "custom_icon_audio") do
    Controller.User.icon_audio(model.user)["url"]
  end

  def load_virtual_field(model, "custom_icon_image") do
    Controller.User.icon_image(model.user)["url"]
  end

  def load_virtual_field(model, "custom_icon_video") do
    Controller.User.icon_video(model.user)["url"]
  end

  def load_virtual_field(model, "custom_logo") do
    Controller.User.logo(model.user)["url"]
  end

  def load_virtual_field(model, "custom_player_settings") do
    Controller.User.player_settings(model.user)
  end

  def build_params_create_new_project(current_user, mv_project) do
    project_params = %{
      "author" => current_user.display_name,
      "name" => Map.get(mv_project, "name"),
      "user_id" => current_user.id,
      "visibility" => "private",
      "mv_project_id" => Map.get(mv_project, "id"),
      "published?" => false
    }

    case create(project_params) do
      {:ok, %Project{} = project_struct} ->
        {:ok, project_struct}

      {:error, reason} ->
        Logger.error("Project creation failed while adding mv_project: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def add_project_assets_to_fader(user_params, mv_asset_list, project_struct) do
    result =
      Enum.map(mv_asset_list, fn mv_asset ->
        create_and_assign(user_params, mv_asset, project_struct)
      end)
      |> Enum.split_with(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    case result do
      {ok_tuples, []} ->
        asset_leases = Enum.map(ok_tuples, fn {:ok, asset_lease} -> asset_lease end)
        {:ok, asset_leases}

      {_, errors} ->
        Enum.each(errors, fn {:error, reason} ->
          Logger.error("Custom error message in mv_projects: #{inspect(reason)}")
        end)

        {:error, "Error adding project to Fader"}
    end
  end

  def download_project_assets(user_params, asset_leases) do
    Enum.each(asset_leases, fn asset_lease ->
      if asset_lease.asset.status == "ready" do
        :ok
      else
        Downloader.add_download_params(create_params(user_params, asset_lease.asset))
      end
    end)
  end

  def fetch_mv_project_assets(mv_node, mv_token, mv_project_id, current_page) do
    case MvApiClient.fetch_project_assets(mv_node, mv_token, mv_project_id, current_page) do
      {:ok, mv_project_assets} ->
        {:ok, mv_project_assets}

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse while fetching subtitles: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def create_project_result_file_path(published_project_base_path, project_data_filename) do
    case File.mkdir_p(published_project_base_path) do
      :ok ->
        path = Path.join([published_project_base_path, project_data_filename])
        {:ok, path}

      {:error, _} ->
        {:error, "Unable to create the project result file path"}
    end
  end

  def is_mv_project?(mv_project_id) do
    not is_nil(mv_project_id)
  end

  def project_publish_status(published?) do
    case published? do
      true -> {:error, :project_published}
      false -> :ok
      nil -> :ok
    end
  end

  defp create_and_assign(user_params, mv_asset, project_struct) do
    current_user = user_params.current_user
    params = create_params(user_params, mv_asset)
    database_params = Controller.Asset.build_asset_params(params)

    with {:ok, asset_lease} <-
           Controller.Asset.add_asset_to_database(database_params, current_user),
         {:ok, asset_lease} <-
           Controller.AssetLease.assign_project(asset_lease, current_user, project_struct) do
      {:ok, asset_lease}
    else
      {:ok, %{"message" => message}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

        {:error, message}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        {:error, reason}

      {:error, reason} ->
        Logger.error("Error while adding asset lease to project while adding mv_project: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp create_params(user_params, asset_struct = %Asset{}) do
    current_user = user_params.current_user
    mv_node = user_params.mv_node
    mv_token = user_params.mv_token

    %{
      media_type: asset_struct.media_type,
      mv_asset_key: asset_struct.mv_asset_key,
      mv_asset_deeplink_key: asset_struct.mv_asset_deeplink_key,
      mv_node: mv_node,
      mv_token: mv_token,
      mv_asset_filename: asset_struct.name,
      current_user: current_user,
      asset_struct: asset_struct
    }
  end

  defp create_params(user_params, mv_asset) do
    current_user = user_params.current_user
    mv_node = current_user.mv_node
    mv_token = user_params.mv_token

    %{
      media_type: Map.get(mv_asset, "contentType"),
      mv_asset_key: Map.get(mv_asset, "key"),
      mv_asset_deeplink_key: Map.get(mv_asset, "deepLinkKey"),
      mv_node: mv_node,
      mv_token: mv_token,
      mv_asset_filename: Map.get(mv_asset, "originalFilename"),
      current_user: current_user
    }
  end

  defp get_project_assets_mediaverse_ids(project) do
    project_with_asset_leases = Repo.preload(project, asset_leases: :asset)

    Enum.map(project_with_asset_leases.asset_leases, fn project_asset_lease ->
      project_asset_lease.asset.mv_asset_key
    end)
  end
end

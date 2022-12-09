defmodule Darth.Controller.Project do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.Controller

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

    params = Map.put_new(params, "visibility", :private)

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

  def duplicate(project, name) do
    params = %{
      "name" => name,
      "data" => project.data,
      "user_id" => project.user_id
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
      |> where([p], p.visibility == "discoverable")
      |> where([p], p.id != ^id)
      |> join(:inner, [p], u in assoc(p, :user), on: u.id == ^user.id)

    query(params, custom_query)
  end

  def has_primary_asset_lease?(project), do: not is_nil(project.primary_asset_lease_id)

  #
  # INTERNAL FUNCTIONS
  #

  defp delete_repo({:ok, project}) do
    broadcast("projects", {:project_deleted, project})
  end

  defp delete_repo(err), do: err

  defp copy_primary_asset_lease(_project, nil), do: :ok

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
end

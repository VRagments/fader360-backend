defmodule Darth.Controller.AssetLease do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.Controller
  alias Darth.Model.{AssetLease, User}

  def model_mod(), do: Darth.Model.AssetLease
  def default_query_sort_by(), do: "updated_at"
  def default_query_sort_by_secondary(), do: "name"

  def default_select_fields() do
    ~w(
      asset_id
      id
      inserted_at
      license
      updated_at
      valid_since
      valid_until
    )a
  end

  def default_preload_assocs() do
    ~w(
      asset
      projects
    )a
  end

  def new(asset_id, license \\ :owner, valid_since \\ nil, valid_until \\ nil) do
    valid_since = if valid_since, do: valid_since, else: DateTime.utc_now()

    params = %{
      asset_id: asset_id,
      license: license,
      valid_since: valid_since,
      valid_until: valid_until
    }

    %AssetLease{}
    |> AssetLease.changeset(params)
  end

  def create(%Asset{id: asset_id}, license) do
    asset_id
    |> new(license)
    |> Repo.insert()
  end

  def create_for_user_project(%Asset{id: asset_id}, %User{} = user, %Project{} = project) do
    asset_id
    |> new()
    |> Ecto.Changeset.put_assoc(:users, [user])
    |> Ecto.Changeset.put_assoc(:projects, [project])
    |> Repo.insert()
  end

  def create_for_user(%Asset{id: asset_id}, %User{} = user) do
    asset_lease_tuple =
      asset_id
      |> new()
      |> Ecto.Changeset.put_assoc(:users, [user])
      |> Repo.insert()

    case asset_lease_tuple do
      {:ok, asset_lease} ->
        Phoenix.PubSub.broadcast(Darth.PubSub, "asset_leases", {:asset_lease_created, asset_lease})

      _ ->
        nil
    end

    asset_lease_tuple
  end

  def create_for_user_with_license(%Asset{id: asset_id}, %User{} = user, license) do
    asset_lease_tuple =
      asset_id
      |> new(license)
      |> Ecto.Changeset.put_assoc(:users, [user])
      |> Repo.insert()

    case asset_lease_tuple do
      {:ok, asset_lease} ->
        Phoenix.PubSub.broadcast(Darth.PubSub, "asset_leases", {:asset_lease_created, asset_lease})

      _ ->
        nil
    end

    asset_lease_tuple
  end

  def has_project?(%AssetLease{} = lease, %Project{} = project) do
    lease = Repo.preload(lease, :projects)

    lease.projects
    |> Enum.find(&(&1.id == project.id))
    |> is_nil()
    |> Kernel.not()
  end

  def has_project?(%AssetLease{} = lease, project_id) do
    with {:ok, project} <- Controller.Project.read(project_id) do
      has_project?(lease, project)
    end
  end

  def has_project?(lease_id, project_id) do
    with {:ok, lease} <- read(lease_id) do
      has_project?(lease, project_id)
    end
  end

  def remove_project(%AssetLease{} = lease, %Project{} = project) do
    lease = Repo.preload(lease, :projects)

    new_projects =
      lease
      |> Map.get(:projects)
      |> Enum.filter(&(&1.id != project.id))

    asset_lease_tuple =
      lease
      |> AssetLease.changeset()
      |> Ecto.Changeset.put_assoc(:projects, new_projects)
      |> Repo.update()

    case asset_lease_tuple do
      {:ok, asset_lease} ->
        Phoenix.PubSub.broadcast(Darth.PubSub, "asset_leases", {:unassigned_project, asset_lease})

      _ ->
        nil
    end

    asset_lease_tuple
  end

  def remove_user_projects(%AssetLease{} = lease, %User{} = user) do
    lease = Repo.preload(lease, :projects)

    project_ids =
      lease.projects
      |> Enum.filter(&(&1.user_id == user.id))
      |> Enum.map(& &1.id)

    new_projects =
      lease
      |> Map.get(:projects)
      |> Enum.filter(&(&1.id not in project_ids))

    asset_lease_tuple =
      lease
      |> AssetLease.changeset()
      |> Ecto.Changeset.put_assoc(:projects, new_projects)
      |> Repo.update()

    case asset_lease_tuple do
      {:ok, asset_lease} ->
        Phoenix.PubSub.broadcast(Darth.PubSub, "asset_leases", {:asset_lease_updated, asset_lease})

      _ ->
        nil
    end

    asset_lease_tuple
  end

  def remove_user(%AssetLease{} = lease, %User{} = user) do
    lease = Repo.preload(lease, :users)

    asset_lease_tuple =
      lease
      |> AssetLease.changeset()
      |> Ecto.Changeset.put_assoc(:users, Map.get(lease, :users) -- [user])
      |> Repo.update()

    case asset_lease_tuple do
      {:ok, asset_lease} ->
        Phoenix.PubSub.broadcast(Darth.PubSub, "asset_leases", {:asset_lease_updated, asset_lease})

      _ ->
        nil
    end

    asset_lease_tuple
  end

  def has_user?(%AssetLease{} = lease, %User{} = user) do
    lease = Repo.preload(lease, :users)

    lease.users
    |> Enum.find(&(&1.id == user.id))
    |> is_nil()
    |> Kernel.not()
  end

  def has_user?(%AssetLease{} = lease, user_id) do
    with {:ok, user} <- Controller.User.read(user_id) do
      has_user?(lease, user)
    end
  end

  def has_user?(lease_id, user_id) do
    with {:ok, lease} <- read(lease_id) do
      has_user?(lease, user_id)
    end
  end

  def assign(%AssetLease{license: license}, _user) when license != :public, do: {:error, :invalid_lease_license}

  def assign(%AssetLease{} = lease, %User{} = user) do
    if valid_now?(lease) do
      lease = Repo.preload(lease, :users)

      if has_user?(lease, user) do
        {:error, :user_already_assigned}
      else
        add_user(lease, user)
      end
    else
      {:error, :lease_not_valid}
    end
  end

  def assign_project(%AssetLease{} = lease, %User{} = user, %Project{} = project) do
    if valid_now?(lease) do
      lease = Repo.preload(lease, [:users, :projects])

      cond do
        not has_user?(lease, user) ->
          {:error, :user_not_assigned}

        has_project?(lease, project) ->
          {:error, :project_already_assigned}

        project.user_id != user.id ->
          {:error, :user_not_project_owner}

        true ->
          add_project(lease, project)
      end
    else
      {:error, :lease_not_valid}
    end
  end

  def assign_project(%AssetLease{} = lease, %User{} = user, project_id) do
    with {:ok, project} <- Controller.Project.read(project_id) do
      assign_project(lease, user, project)
    end
  end

  def unassign_project(%AssetLease{} = lease, %User{} = user, %Project{} = project) do
    lease = Repo.preload(lease, [:users, :projects])

    cond do
      not has_user?(lease, user) ->
        {:error, :user_not_assigned}

      not has_project?(lease, project) ->
        {:error, :project_assigned}

      project.user_id != user.id ->
        {:error, :user_not_project_owner}

      true ->
        remove_project(lease, project)
    end
  end

  def unassign_project(%AssetLease{} = lease, %User{} = user, project_id) do
    with {:ok, project} <- Controller.Project.read(project_id) do
      unassign_project(lease, user, project)
    end
  end

  def is_owner?(%AssetLease{} = lease, %User{} = user) do
    lease = Repo.preload(lease, :users)

    if lease.license == :owner do
      # if the lease is the owner lease, we just need to verify the user id
      length(lease.users) == 1 and Map.get(List.first(lease.users), :id) == user.id
    else
      # if the lease is not the owner lease, we first need to get the owner lease beforei verifying the user id
      owner_lease =
        lease
        |> Repo.preload(asset: :asset_leases)
        |> Map.get(:asset)
        |> Map.get(:asset_leases)
        |> Enum.find(&(&1.license == :owner))
        |> Repo.preload(:users)

      length(owner_lease.users) == 1 and Map.get(List.first(owner_lease.users), :id) == user.id
    end
  end

  def query_by_public_project(project_id, params, only_ready \\ true) do
    custom_query =
      AssetLease
      |> base_query(only_ready)
      |> join(:inner, [al], p in assoc(al, :projects), on: p.id == ^project_id)

    query(params, custom_query, true, Darth.Model.Asset)
  end

  def optimized_by_public_project(project_id) do
    leases =
      AssetLease
      |> join(:inner, [al], p in assoc(al, :projects), on: p.id == ^project_id)
      |> join(:inner, [al], a in assoc(al, :asset), on: a.status == "ready")
      |> Repo.all()

    %{
      entries: leases,
      total_entries: length(leases)
    }
  end

  def query_by_accessible_project(project_id, params, only_ready \\ true) do
    custom_query =
      AssetLease
      |> base_query(only_ready)
      |> join(:inner, [al], p in assoc(al, :projects), on: p.id == ^project_id)

    query(params, custom_query, true, Darth.Model.Asset)
  end

  def query_by_user(user_id, params, only_ready \\ true) do
    custom_query =
      AssetLease
      |> base_query(only_ready)
      |> join(:inner, [al], u in assoc(al, :users), on: u.id == ^user_id)

    query(params, custom_query, true, Darth.Model.Asset)
  end

  def query_by_license(license, params, only_ready \\ true, valid_now \\ true) do
    custom_query =
      AssetLease
      |> base_query(only_ready)
      |> where([al], al.license == ^license)

    custom_query =
      if valid_now do
        query_valid_now(custom_query)
      else
        custom_query
      end

    query(params, custom_query, true, Darth.Model.Asset)
  end

  def query_by_user_license_type(user_id, license, type, params \\ %{}) do
    type_check = "#{type}/%"

    custom_query =
      AssetLease
      |> base_query()
      |> where([al], al.license == ^license)
      |> join(:inner, [al], u in assoc(al, :users), on: u.id == ^user_id)
      |> join(:inner, [al, u], a in assoc(al, :asset), on: ilike(a.media_type, ^type_check))

    query(params, custom_query, true, Darth.Model.Asset)
  end

  def disable(%AssetLease{} = lease) do
    lease
    |> AssetLease.changeset(%{valid_until: DateTime.utc_now()})
    |> Repo.update()
  end

  def read_by_project(project_id, lease_id) do
    AssetLease
    |> where([al], al.id == ^lease_id)
    |> join(:inner, [al], p in assoc(al, :projects), on: p.id == ^project_id)
    |> preload([al], [:projects, :asset])
    |> Repo.one()
  end

  def read_by_user_and_asset(user_id, asset_id) do
    AssetLease
    |> where([al], al.asset_id == ^asset_id)
    |> join(:inner, [al], u in assoc(al, :users), on: u.id == ^user_id)
    |> preload([al], [:asset])
    |> Repo.one()
  end

  # TODO: check if this is the last lease (owner), if so, delete the asset as well
  def maybe_delete(%AssetLease{} = al) do
    al = Repo.preload(al, :users)

    if Enum.empty?(al.users) do
      al |> AssetLease.delete_changeset() |> Repo.delete() |> delete_repo()
    else
      {:error, :lease_has_users}
    end
  end

  def maybe_delete(nil), do: {:error, :not_found}
  def maybe_delete(id), do: AssetLease |> Repo.get(id) |> maybe_delete()

  @doc """
  Determine currently valid leases of an asset
  """
  def current_leases(%Asset{id: a_id}) do
    AssetLease
    |> where([al], al.asset_id == ^a_id)
    |> query_valid_now()
    |> Repo.all()
  end

  def valid_now?(%AssetLease{valid_since: valid_since, valid_until: valid_until}) do
    now = DateTime.utc_now()

    DateTime.compare(valid_since, now) == :lt and
      (is_nil(valid_until) or DateTime.compare(now, valid_until) == :lt)
  end

  def total_number_of_assets(opts0 \\ []) do
    default_opts = [
      license: nil,
      media_type_prefix: nil,
      only_valid_now: true,
      owner_userame: nil,
      project: nil,
      status: nil,
      user: nil
    ]

    opts = Keyword.merge(default_opts, opts0)

    AssetLease
    |> (fn q ->
          if is_nil(opts[:license]), do: q, else: where(q, [al], al.license == ^opts[:license])
        end).()
    |> (fn q ->
          cond do
            is_nil(opts[:media_type_prefix]) and is_nil(opts[:status]) ->
              join(q, :inner, [al], a in assoc(al, :asset))

            is_nil(opts[:status]) ->
              check = "#{opts[:media_type_prefix]}%"
              join(q, :inner, [al], a in assoc(al, :asset), on: ilike(a.media_type, ^check))

            is_nil(opts[:media_type_prefix]) ->
              join(q, :inner, [al], a in assoc(al, :asset), on: a.status == ^opts[:status])

            true ->
              check = "#{opts[:media_type_prefix]}%"

              join(
                q,
                :inner,
                [al],
                a in assoc(al, :asset),
                on: ilike(a.media_type, ^check) and a.status == ^opts[:status]
              )
          end
        end).()
    |> (fn q ->
          if is_nil(opts[:owner_username]) do
            q
          else
            q
            |> join(:left, [al, a], o in subquery(owner_subquery()), on: o.asset_id == al.asset_id)
            |> where([al, a, o], o.owner_username == ^opts[:owner_username])
          end
        end).()
    |> (fn q ->
          if is_nil(opts[:project]) do
            q
          else
            join(q, :inner, [al], p in assoc(al, :projects), on: p.id == ^opts[:project])
          end
        end).()
    |> (fn q ->
          if is_nil(opts[:user]) do
            q
          else
            join(q, :inner, [al], u in assoc(al, :users), on: u.id == ^opts[:user])
          end
        end).()
    |> (fn q ->
          if opts[:only_valid_now] do
            query_valid_now(q)
          else
            q
          end
        end).()
    |> select([al, a], count(a.id, :distinct))
    |> Repo.one()
  end

  def query_ready(query, only_ready \\ true, primary_model \\ true)

  def query_ready(query, false, true) do
    join(query, :inner, [al], a in assoc(al, :asset))
  end

  def query_ready(query, false, false), do: query

  def query_ready(query, true, true) do
    join(query, :inner, [al], a in assoc(al, :asset), on: a.status == "ready")
  end

  def query_ready(query, true, false) do
    where(query, [a, al], a.status == "ready")
  end

  def query_valid_now(query) do
    now = DateTime.utc_now()
    where(query, [al], al.valid_since < ^now and (is_nil(al.valid_until) or al.valid_until > ^now))
  end

  def is_part_of_project?(asset_lease, project) do
    Enum.any?(asset_lease.projects, fn proj -> proj.id == project.id end)
  end

  def is_primary_asset_lease?(project, asset_lease), do: project.primary_asset_lease_id == asset_lease.id

  #
  # INTERNAL FUNCTIONS
  #
  defp add_project(%AssetLease{} = lease, %Project{} = project) do
    lease = Repo.preload(lease, :projects)

    asset_lease_tuple =
      lease
      |> AssetLease.changeset()
      |> Ecto.Changeset.put_assoc(:projects, [project | Map.get(lease, :projects)])
      |> Repo.update()

    case asset_lease_tuple do
      {:ok, asset_lease} ->
        Phoenix.PubSub.broadcast(Darth.PubSub, "asset_leases", {:assigned_project, asset_lease})

      _ ->
        nil
    end

    asset_lease_tuple
  end

  def add_user(%AssetLease{} = lease, %User{} = user) do
    lease = Repo.preload(lease, :users)

    lease
    |> AssetLease.changeset()
    |> Ecto.Changeset.put_assoc(:users, [user | Map.get(lease, :users)])
    |> Repo.update()
  end

  defp delete_repo({:ok, _}), do: :ok
  defp delete_repo(err), do: err

  defp base_query(query, only_ready \\ true) do
    query
    |> query_ready(only_ready)
    |> join(:left, [al, a], o in subquery(owner_subquery()), on: o.asset_id == al.asset_id)
    |> select_merge([al, a, o], %{owner_username: o.owner_username})
  end

  defp owner_subquery do
    AssetLease
    |> where([al], al.license == :owner)
    |> join(:inner, [al], u in assoc(al, :users))
    |> select([al, u], %{asset_id: al.asset_id, owner_username: u.username})
  end
end

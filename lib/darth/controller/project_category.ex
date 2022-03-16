defmodule Darth.Controller.ProjectCategory do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.Model.ProjectCategory

  def model_mod, do: Darth.Model.ProjectCategory
  def default_query_sort_by, do: "updated_at"

  def default_select_fields do
    ~w(
      id
      name
    )a
  end

  def default_preload_assocs do
    ~w(
    )a
  end

  def new(params) do
    ProjectCategory.changeset(%ProjectCategory{}, params)
  end

  def create(params) do
    with {:ok, p} <- params |> new() |> Repo.insert(), do: read(p.id)
  end

  def update({:error, _} = err, _), do: err
  def update({:ok, project_category}, params), do: update(project_category, params)

  def update(%ProjectCategory{} = project_category, params) do
    project_category
    |> ProjectCategory.changeset(params)
    |> Repo.update()
  end

  def update(id, params), do: id |> read() |> update(params)

  def list_by_ids(ids) do
    ProjectCategory
    |> where([pc], pc.id in ^ids)
    |> Repo.all()
  end

  def delete(%ProjectCategory{} = pt), do: pt |> Repo.delete() |> delete_repo()
  def delete(nil), do: {:error, :not_found}
  def delete(id), do: ProjectCategory |> Repo.get(id) |> delete

  @doc """
  Returns all project_categories by only their ids.
  """
  def all_multiple_select() do
    ProjectCategory
    |> select([:id, :name])
    |> Repo.all()
    |> Enum.map(&{&1.name, &1.id})
  end

  #
  # INTERNAL FUNCTIONS
  #
  defp delete_repo({:ok, _}), do: :ok
  defp delete_repo(err), do: err
end

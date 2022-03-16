defmodule Darth.Controller do
  @moduledoc false

  @callback model_mod() :: nil | atom
  @callback default_query_sort_by() :: nil | String.t()
  @callback default_query_sort_by_secondary() :: nil | String.t()
  @callback default_select_fields() :: list
  @callback default_preload_assocs() :: list

  defmacro __using__(opts) do
    quote do
      #
      # Bahviour definition
      #

      @behaviour Darth.Controller

      def model_mod, do: nil
      def default_query_sort_by, do: nil
      def default_query_sort_by_secondary, do: nil
      def default_select_fields, do: []
      def default_preload_assocs, do: []

      defoverridable model_mod: 0,
                     default_query_sort_by: 0,
                     default_query_sort_by_secondary: 0,
                     default_select_fields: 0,
                     default_preload_assocs: 0

      #
      # Basic controller functions
      #

      require Logger

      import Ecto

      import Ecto.Query,
        only: [
          distinct: 2,
          from: 1,
          from: 2,
          where: 2,
          where: 3,
          preload: 2,
          preload: 3,
          join: 4,
          join: 5,
          order_by: 2,
          order_by: 3,
          select: 2,
          select: 3,
          select_merge: 3
        ]

      alias Darth.Repo
      alias Darth.Model.{Asset, Project}

      defp broadcast(topic, payload) do
        Phoenix.PubSub.broadcast(Darth.PubSub, topic, payload)
      end

      if unquote(opts)[:include_crud] do
        def read(id, preload \\ true, extra_fields \\ [], include_default_fields \\ true)
        def read("", _, _, _), do: {:error, :not_found}

        def read(id, preload, extra_fields, include_default_fields) do
          fields =
            if not is_nil(include_default_fields) and include_default_fields do
              default_select_fields() ++ extra_fields
            else
              extra_fields
            end

          fields = for f <- fields, f in model_mod().__schema__(:fields), do: f

          res0 =
            model_mod()
            |> preload_assoc(preload)
            |> select(^fields)
            |> Repo.get(id)

          if is_nil(res0) do
            {:error, :not_found}
          else
            res1 = preload_virtual_fields(res0)
            {:ok, res1}
          end
        end

        def read_by(params, preload \\ true, extra_fields \\ [], include_default_fields \\ true) do
          fields =
            if not is_nil(include_default_fields) and include_default_fields do
              default_select_fields() ++ extra_fields
            else
              extra_fields
            end

          fields = for f <- fields, f in model_mod().__schema__(:fields), do: f

          res =
            model_mod()
            |> preload_assoc(preload)
            |> select(^fields)
            |> Repo.get_by(params)

          if is_nil(res) do
            {:error, :not_found}
          else
            {:ok, res}
          end
        end

        def query(params, query \\ model_mod(), preload \\ false, secondary_model \\ nil) do
          params =
            if is_nil(secondary_model) do
              Map.put(params, "search_attrs", model_mod().search_attributes())
            else
              Map.put(params, "search_attrs", secondary_model.search_attributes())
            end

          sort_params = %{
            "sort_by" => default_query_sort_by(),
            "sort_dir" => "desc",
            "sort_by_secondary" => default_query_sort_by_secondary(),
            "sort_dir_secondary" => "desc"
          }

          Repo.list_query(
            model_mod(),
            query,
            params,
            &__MODULE__.preload_assoc(&1, preload),
            sort_params,
            secondary_model
          )
        end

        def preload_assoc(query, assocs \\ true)
        def preload_assoc(query, true), do: preload_assoc(query, default_preload_assocs())

        def preload_assoc(query, assocs) when is_list(assocs) do
          preload(query, ^assocs)
        end

        def preload_assoc(query, _), do: query

        defp preload_virtual_fields(model) do
          virtual_fields =
            try do
              model_mod().virtual_attributes()
            rescue
              UndefinedFunctionError ->
                []
            end

          Enum.reduce(virtual_fields, model, fn f, acc ->
            try do
              v = apply(__MODULE__, :load_virtual_field, [model, f])
              Map.put(acc, String.to_atom(f), v)
            rescue
              UndefinedFunctionError ->
                acc
            end
          end)
        end
      end
    end
  end

  def ensure_project_access_allowed(user, project_id, fun, only_as_owner \\ true) do
    with {:ok, project} <- Darth.Controller.Project.read(project_id) do
      is_owner = not is_nil(user) and project.user_id == user.id

      if not only_as_owner or is_owner do
        fun.(user, is_owner, project)
      else
        {:error, :not_found}
      end
    end
  end
end

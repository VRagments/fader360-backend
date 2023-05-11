defmodule Darth.Repo do
  use Ecto.Repo,
    otp_app: :darth,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 12
  import Ecto.Query

  @default_query_sort_by "updated_at"
  @default_query_sort_dir "desc"
  @default_query_sort_by_secondary "id"
  @default_query_sort_dir_secondary "asc"
  @default_query_page "1"
  @default_query_size "12"
  @default_query_all "false"
  @default_query_search_attrs []
  @default_paginate_page 1
  @default_paginate_size 12

  @doc """
  Performs a database list query and returns the objects and query metadata based on the given parameters.

  Supported `params`:

  - `all`: Defines whether paging should be performed or not.
  - `attributes`: Comma-separated list of model attributes to be returned.
  - `filters`: Comma-separated list of filter definition for the query.
  - `size`: Defines the paging size for the query.
  - `sort_by`: Defines the attribute by which the list will be ordered
  - `sort_dir`: Defines the direction into which the list will be ordered, `asc` or `desc`.
  - `page`: Defines the page which should be returned.

  """
  def list_query(model, query, params, preload_fun, defaults \\ %{}, secondary_model \\ nil) do
    # This a workaround to get resubmittion via the the web search working
    params = if params["size_change"], do: params["size_change"], else: params

    sort_by = string_to_atom(Map.get(params, "sort_by", Map.get(defaults, "sort_by", @default_query_sort_by)))

    sort_dir = Map.get(params, "sort_dir", Map.get(defaults, "sort_dir", @default_query_sort_dir))

    sort_by_secondary =
      string_to_atom(
        Map.get(
          params,
          "sort_by_secondary",
          Map.get(defaults, "sort_by_secondary", @default_query_sort_by_secondary) ||
            @default_query_sort_by_secondary
        ) || @default_query_sort_by_secondary
      )

    sort_dir_secondary =
      Map.get(
        params,
        "sort_dir_secondary",
        Map.get(defaults, "sort_dir_secondary", @default_query_sort_dir_secondary) ||
          @default_query_sort_dir_secondary
      ) || @default_query_sort_dir_secondary

    all =
      params
      |> Map.get("all", Map.get(defaults, "all", @default_query_all))
      |> (&(&1 == "true")).()

    page = String.to_integer(Map.get(params, "page", Map.get(defaults, "page", @default_query_page)))

    size = String.to_integer(Map.get(params, "size", Map.get(defaults, "size", @default_query_size)))

    attrs = get_attributes(params, model, secondary_model)

    search_attrs =
      Map.get(
        params,
        "search_attrs",
        Map.get(defaults, "search_attrs", @default_query_search_attrs)
      )

    filters = if params["filters"], do: String.split(params["filters"], ";"), else: []

    if all do
      entries =
        query
        |> maybe_sort(
          sort_by,
          sort_dir,
          sort_by_secondary,
          sort_dir_secondary,
          model,
          secondary_model
        )
        |> process_filters(filters, search_attrs, secondary_model)
        |> preload_fun.()
        |> all()
        |> maybe_sort_virtual(
          sort_by,
          sort_dir,
          sort_by_secondary,
          sort_dir_secondary,
          model,
          secondary_model
        )

      total = length(entries)

      %{
        attributes: attrs,
        entries: entries,
        total_entries: total
      }
    else
      page = if page <= 0, do: @default_paginate_page, else: page
      size = if size <= 0, do: @default_paginate_size, else: size

      query = process_filters(query, filters, search_attrs, secondary_model)

      total =
        query
        |> exclude(:select)
        |> select(fragment("count(*)"))
        |> one()

      entries =
        query
        |> maybe_sort(
          sort_by,
          sort_dir,
          sort_by_secondary,
          sort_dir_secondary,
          model,
          secondary_model
        )
        |> limit(^size)
        |> offset(^((page - 1) * size))
        |> preload_fun.()
        |> all()
        |> maybe_sort_virtual(
          sort_by,
          sort_dir,
          sort_by_secondary,
          sort_dir_secondary,
          model,
          secondary_model
        )

      total_pages = div(total, size)
      total_pages = if rem(total, size) > 0, do: total_pages + 1, else: total_pages

      %{
        attributes: attrs,
        entries: entries,
        query_page: page,
        query_search_attrs: search_attrs,
        query_size: size,
        query_sort_by: sort_by,
        query_sort_dir: sort_dir,
        query_sort_by_secondary: sort_by_secondary,
        query_sort_dir_secondary: sort_dir_secondary,
        total_entries: total,
        total_pages: total_pages
      }
    end
  end

  @doc """
  Returns a list of attributes extracted from the given parameter map.
  """
  def get_attributes(params, model, secondary_model \\ nil) do
    attrs = if params["attributes"], do: String.split(params["attributes"], ","), else: []
    attrs = for(a <- attrs, do: string_to_atom(a))

    virtual_fields =
      try do
        if is_nil(secondary_model) do
          model.virtual_attributes()
        else
          secondary_model.virtual_attributes()
        end
      rescue
        UndefinedFunctionError ->
          []
      end

    valid_fields =
      if is_nil(secondary_model) do
        model.__schema__(:fields) ++ model.__schema__(:associations) ++ virtual_fields
      else
        secondary_model.__schema__(:fields) ++
          secondary_model.__schema__(:associations) ++ virtual_fields
      end

    if is_nil(secondary_model) and is_nil(model) do
      attrs
    else
      for a <- attrs, a in valid_fields, do: a
    end
  end

  defp sort(query, sort_by, sort_dir, secondary_model \\ nil)
  defp sort(query, nil, _sort_dir, _secondary_model), do: query
  defp sort(query, sort_by, "desc", nil), do: order_by(query, [m], desc: field(m, ^sort_by))
  defp sort(query, sort_by, _, nil), do: order_by(query, [m], asc: field(m, ^sort_by))
  defp sort(query, sort_by, "desc", _), do: order_by(query, [m0, m], desc: field(m, ^sort_by))
  defp sort(query, sort_by, _, _), do: order_by(query, [m0, m], asc: field(m, ^sort_by))

  defp process_filters(query, [], _, _), do: query

  defp process_filters(query, filters, search_attrs, secondary_model) do
    Enum.reduce(filters, query, fn f, acc ->
      parts = f |> String.trim() |> String.split(",") |> Enum.map(&String.trim/1)

      with [a, op, b] <- parts do
        a = string_to_atom(a)
        process_filters_query(op, search_attrs, secondary_model, acc, a, b)
      else
        _ ->
          acc
      end
    end)
  end

  defp process_filters_query(">", _, true, query, a, b), do: where(query, [m], field(m, ^a) > ^b)

  defp process_filters_query(">", _, false, query, a, b),
    do: where(query, [m0, m], field(m, ^a) > ^b)

  defp process_filters_query(">=", _, true, query, a, b),
    do: where(query, [m], field(m, ^a) >= ^b)

  defp process_filters_query(">=", _, false, query, a, b),
    do: where(query, [m0, m], field(m, ^a) >= ^b)

  defp process_filters_query("<", _, true, query, a, b), do: where(query, [m], field(m, ^a) < ^b)

  defp process_filters_query("<", _, false, query, a, b),
    do: where(query, [m0, m], field(m, ^a) < ^b)

  defp process_filters_query("<=", _, true, query, a, b),
    do: where(query, [m], field(m, ^a) <= ^b)

  defp process_filters_query("<=", _, false, query, a, b),
    do: where(query, [m0, m], field(m, ^a) <= ^b)

  defp process_filters_query("==", _, true, query, a, b),
    do: where(query, [m], field(m, ^a) == ^b)

  defp process_filters_query("==", _, false, query, a, b),
    do: where(query, [m0, m], field(m, ^a) == ^b)

  defp process_filters_query("!=", _, true, query, a, b),
    do: where(query, [m], field(m, ^a) != ^b)

  defp process_filters_query("!=", _, false, query, a, b),
    do: where(query, [m0, m], field(m, ^a) != ^b)

  defp process_filters_query(op, search_attrs, secondary_model, query, a, b)
       when op in ["~", "~=", "=~", "~*"] do
    process_search(query, op, to_string(a), b, search_attrs, secondary_model)
  end

  defp process_filters_query(_op, _search_attrs, _secondary_model, query, _a, _b), do: query

  defp process_search(query, _op, _attr, "", _attributes, _secondary_model), do: query
  defp process_search(query, _op, _attr, [], _attributes, _secondary_model), do: query

  defp process_search(query, op, attr, search, attributes, secondary_model) do
    subquery =
      search
      |> String.trim()
      |> String.split(" ")
      |> Enum.reduce(false, fn p0, acc ->
        Enum.reduce(
          attributes,
          acc,
          &process_search_attribute(&2, op, attr, p0, &1, secondary_model)
        )
      end)

    if is_nil(secondary_model) do
      where(query, [m], ^subquery)
    else
      where(query, [m0, m], ^subquery)
    end
  end

  defp process_search_attribute(
         query,
         op,
         attr0,
         search_part,
         {attr1, _refmodel},
         secondary_model
       )
       when attr0 == attr1 do
    attr = string_to_atom(attr0)
    p = process_search_op(op, search_part)

    if is_nil(secondary_model) do
      dynamic([m0, m], ilike(field(m, ^attr), ^p) or ^query)
    else
      dynamic([m0, m1, m], ilike(field(m, ^attr), ^p) or ^query)
    end
  end

  defp process_search_attribute(query, op, attr0, search_part, attr1, secondary_model)
       when attr0 == attr1 do
    attr = string_to_atom(attr0)
    p = process_search_op(op, search_part)

    if is_nil(secondary_model) do
      dynamic([m], ilike(field(m, ^attr), ^p) or ^query)
    else
      dynamic([m0, m], ilike(field(m, ^attr), ^p) or ^query)
    end
  end

  defp process_search_attribute(query, _op, _attr, _search_part, _attributes, _secondary_model),
    do: query

  defp process_search_op("~", part), do: "#{part}"
  defp process_search_op("~*", part), do: "%#{part}%"
  defp process_search_op("~=", part), do: "%#{part}"
  defp process_search_op("=~", part), do: "#{part}%"
  defp process_search_op(_, part), do: part

  defp sort_by_virtual(entries, sort_by, sort_dir) do
    op = if sort_dir == "asc", do: :<, else: :>
    Enum.sort(entries, &apply(:erlang, op, [Map.get(&1, sort_by), Map.get(&2, sort_by)]))
  end

  defp string_to_atom(string) do
    string |> String.trim() |> String.to_existing_atom()
  end

  # We do DB ordering only if the primary sorting attribute isn't virtual or both aren't
  defp maybe_sort(query, sort_by, sort_dir, sort_by_secondary, sort_dir_secondary, model, nil) do
    cond do
      sort_by in model.__schema__(:fields) and sort_by_secondary in model.__schema__(:fields) ->
        query
        |> sort(sort_by, sort_dir)
        |> sort(sort_by_secondary, sort_dir_secondary)

      sort_by in model.__schema__(:fields) ->
        query
        |> sort(sort_by, sort_dir)

      true ->
        query
    end
  end

  defp maybe_sort(
         query,
         sort_by,
         sort_dir,
         sort_by_secondary,
         sort_dir_secondary,
         _model,
         secondary_model
       ) do
    cond do
      sort_by in secondary_model.__schema__(:fields) and
          sort_by_secondary in secondary_model.__schema__(:fields) ->
        query
        |> sort(sort_by, sort_dir, secondary_model)
        |> sort(sort_by_secondary, sort_dir_secondary, secondary_model)

      sort_by in secondary_model.__schema__(:fields) ->
        query
        |> sort(sort_by, sort_dir, secondary_model)

      true ->
        query
    end
  end

  defp maybe_sort_virtual(
         entries,
         sort_by,
         sort_dir,
         sort_by_secondary,
         sort_dir_secondary,
         model,
         nil
       ) do
    cond do
      sort_by in model.__schema__(:fields) and sort_by_secondary in model.__schema__(:fields) ->
        entries

      sort_by in model.__schema__(:fields) ->
        entries
        |> sort_by_virtual(sort_by_secondary, sort_dir_secondary)

      true ->
        entries
        |> sort_by_virtual(sort_by, sort_dir)
        |> sort_by_virtual(sort_by_secondary, sort_dir_secondary)
    end
  end

  defp maybe_sort_virtual(
         entries,
         _sort_by,
         _sort_dir,
         _sort_by_secondary,
         _sort_dir_secondary,
         _model,
         _secondary_model
       ) do
    # TODO: We can't sort virtual fields on secondary models for now
    entries
  end
end

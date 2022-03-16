defmodule Darth.Statistics do
  @moduledoc false

  require Logger

  import Ecto.Query

  alias Timex.Format.DateTime.{Formatter}
  alias Darth.{Repo}
  alias Darth.Model.{User, Project, Asset}

  def totals(types, res \\ [])
  def totals([], res), do: res
  def totals([:asset | rest], res), do: totals(rest, Keyword.put(res, :asset, nr_assets()))
  def totals([:project | rest], res), do: totals(rest, Keyword.put(res, :project, nr_projects()))
  def totals([:user | rest], res), do: totals(rest, Keyword.put(res, :user, nr_user_accounts()))

  def totals([:user_with_verified_email | rest], res),
    do: totals(rest, Keyword.put(res, :user_with_verified_email, nr_user_accounts_with_email()))

  def totals([:user_with_login | rest], res),
    do: totals(rest, Keyword.put(res, :user_with_login, nr_user_accounts_with_login()))

  def totals([_ | rest], res), do: totals(rest, res)

  #
  # Asset Statistics
  #

  def nr_assets(user_id \\ nil, project_id \\ nil) do
    Asset
    |> select([a], count(a.id))
    |> asset_query(user_id, project_id)
    |> Repo.one()
  end

  def nr_assets_by_type(user_id \\ nil, project_id \\ nil) do
    Asset
    |> asset_query(user_id, project_id)
    |> group_by([a], a.media_type)
    |> select([a], {a.media_type, count(a.id, :distinct)})
    |> Repo.all()
  end

  def asset_growth(range \\ 12, period \\ "month") do
    Asset
    |> base_growth_query(range, period)
    |> Repo.all()
    |> reduce_growth_info(range, period)
  end

  #
  # Project Statistics
  #

  def nr_projects(user_id \\ nil) do
    Project
    |> select([p], count(p.id))
    |> (fn q -> if is_nil(user_id), do: q, else: where(q, [p], p.user_id == ^user_id) end).()
    |> Repo.one()
  end

  def nr_projects_by_visibility(user_id \\ nil) do
    Project
    |> (fn q -> if is_nil(user_id), do: q, else: where(q, [p], p.user_id == ^user_id) end).()
    |> group_by([p], p.visibility)
    |> select([p], {p.visibility, count(p.id)})
    |> Repo.all()
  end

  def nr_projects_with_assets do
    Project
    |> join(:inner, [p], a in assoc(p, :assets))
    |> group_by([p, a], p.id)
    |> select([p, a], {p.id, count(p.id)})
    |> Repo.all()
    |> Enum.reduce([], fn
      {_, 0}, acc ->
        Keyword.update(acc, :none, 1, &(&1 + 1))

      {_, 1}, acc ->
        Keyword.update(acc, :one, 1, &(&1 + 1))

      {_, 2}, acc ->
        Keyword.update(acc, :two, 1, &(&1 + 1))

      {_, 3}, acc ->
        Keyword.update(acc, :three, 1, &(&1 + 1))

      {_, _}, acc ->
        Keyword.update(acc, :more_than_three, 1, &(&1 + 1))
    end)
  end

  def project_growth(range \\ 12, period \\ "month") do
    Project
    |> base_growth_query(range, period)
    |> Repo.all()
    |> reduce_growth_info(range, period)
  end

  #
  # User Statistics
  #

  def nr_users_with_projects do
    User
    |> join(:inner, [u], p in assoc(u, :projects))
    |> group_by([u, p], u.id)
    |> select([u, p], {u.id, count(u.id)})
    |> Repo.all()
    |> Enum.reduce([], fn
      {_, 0}, acc ->
        Keyword.update(acc, :none, 1, &(&1 + 1))

      {_, 1}, acc ->
        Keyword.update(acc, :one, 1, &(&1 + 1))

      {_, 2}, acc ->
        Keyword.update(acc, :two, 1, &(&1 + 1))

      {_, 3}, acc ->
        Keyword.update(acc, :three, 1, &(&1 + 1))

      {_, _}, acc ->
        Keyword.update(acc, :more_than_three, 1, &(&1 + 1))
    end)
  end

  def nr_user_accounts do
    User
    |> select([u], count(u.id))
    |> Repo.one()
  end

  def nr_user_accounts_with_email do
    User
    |> select([u], count(u.id))
    |> where([u], u.is_email_verified == true)
    |> Repo.one()
  end

  def nr_user_accounts_with_login do
    User
    |> select([u], count(u.id))
    |> where([u], not is_nil(u.last_logged_in_at))
    |> Repo.one()
  end

  def user_growth(range \\ 12, period \\ "month") do
    User
    |> base_growth_query(range, period)
    |> Repo.all()
    |> reduce_growth_info(range, period)
  end

  @active_users_types [
    {:daily, 1, "day"},
    {:weekly, 7, "day"},
    {:monthly, 30, "day"}
  ]
  def active_users(from \\ Timex.now()) do
    Enum.map(@active_users_types, fn {type, range, period} ->
      value =
        User
        |> active_users_query(range, period, from)
        |> Repo.one()

      {type, value}
    end)
  end

  def user_retention_base(timeframes) do
    Enum.map(timeframes, fn timeframe_start ->
      timeframe_end = timeframe_start + 1

      value =
        User
        |> where(
          [u],
          fragment("u0.inserted_at BETWEEN ? AND ?", ago(^timeframe_end, "day"), ago(^timeframe_start, "day"))
        )
        |> select([u], count(u.id, :distinct))
        |> Repo.one()

      {timeframe_start, value}
    end)
  end

  def user_retention(timeframes) do
    Enum.map(timeframes, fn timeframe_start ->
      timeframe_end = timeframe_start + 1

      value =
        User
        |> active_users_query(1, "day")
        |> where(
          [u],
          fragment("u0.inserted_at BETWEEN ? AND ?", ago(^timeframe_end, "day"), ago(^timeframe_start, "day"))
        )
        |> Repo.one()

      {timeframe_start, value}
    end)
  end

  #
  # Utility Functions
  #

  def period_key("year", date), do: Formatter.format(Timex.beginning_of_year(date), "{WYYYY}")
  def period_key("month", date), do: Formatter.format(Timex.beginning_of_month(date), "{Mshort} {WYY}")
  def period_key("week", date), do: Formatter.format(Timex.beginning_of_week(date), "{Wiso}/{WYYYY}")
  def period_key("day", date), do: Formatter.format(Timex.beginning_of_day(date), "{D} {Mshort} {WYY}")

  def shift_date(date, "year", nr), do: Timex.shift(date, years: nr)
  def shift_date(date, "month", nr), do: Timex.shift(date, months: nr)
  def shift_date(date, "week", nr), do: Timex.shift(date, weeks: nr)
  def shift_date(date, "day", nr), do: Timex.shift(date, days: nr)

  #
  # INTERNAL FUNCTIONS
  #

  defp reduce_growth_info(objects, range, period) do
    now = Timex.now()

    calc =
      Enum.reduce(objects, %{}, fn {_, inserted_at}, acc ->
        {:ok, key} = period_key(period, inserted_at)
        count = Map.get(acc, key, 0)
        Map.put(acc, key, count + 1)
      end)

    Enum.map(Enum.reverse(0..(range - 1)), fn i ->
      {:ok, key} = period_key(period, shift_date(now, period, -1 * i))
      [key, Map.get(calc, key, 0)]
    end)
  end

  defp base_growth_query(query, range, period) do
    query
    |> where([o], o.inserted_at >= datetime_add(^NaiveDateTime.utc_now(), ^(-range), ^period))
    |> order_by([o], desc: o.inserted_at)
    |> select([o], {o.id, o.inserted_at})
  end

  defp active_users_query(query, range, period, from \\ Timex.now()) do
    query
    |> where([u], u.last_logged_in_at >= datetime_add(^NaiveDateTime.utc_now(), ^(-range), ^period))
    |> where([u], u.last_logged_in_at < ^from)
    |> select([u], count(u.id, :distinct))
  end

  defp asset_query(query, user_id, _project_id) when is_nil(user_id), do: query

  defp asset_query(query, user_id, project_id) when is_nil(project_id),
    do: join(query, :inner, [a], u in assoc(a, :users), on: u.id == ^user_id)

  defp asset_query(query, _user_id, project_id),
    do: join(query, :inner, [a], p in assoc(a, :projects), on: p.id == ^project_id)
end

defmodule Darth.GoogleReportingApi do
  @moduledoc false

  import Ecto.Query

  require Logger

  alias Goth
  alias Darth.{Repo, Statistics}
  alias Darth.Model.{Project}

  @http_option_recv_timeout Application.get_env(:darth, :googla_api_recv_timeout, 15_000)
  @http_option_timeout Application.get_env(:darth, :google_api_call_timeout, 15_000)
  @http_headers [{"Accept-Encoding", "gzip,deflate"}]
  @http_options [
    recv_timeout: @http_option_recv_timeout,
    timeout: @http_option_timeout,
    ssl: [{:versions, [:"tlsv1.2"]}]
  ]

  def page_views_for_user(user_id, range \\ 12, period \\ "month") do
    Project
    |> where([p], p.user_id == ^user_id)
    |> select([p], p.id)
    |> Repo.all()
    |> project_filters()
    |> report_request(report_date_ranges())
    |> request_page_views()
    |> Enum.reduce(%{}, fn {_, views}, acc1 ->
      Enum.reduce(views, acc1, fn {date, count}, acc2 ->
        Map.update(acc2, date, count, &(&1 + count))
      end)
    end)
    |> reduce_counts(range, period)
  end

  def page_views_for_projects(projects, range \\ 12, period \\ "month")
  def page_views_for_projects([], _, _), do: {:ok, []}

  def page_views_for_projects(projects, _, _) when length(projects) > 5 do
    {:error, :max_project_5}
  end

  def page_views_for_projects(projects, range, period) when length(projects) <= 5 do
    projects
    |> project_filters()
    |> report_request(report_date_ranges())
    |> request_page_views()
    |> Enum.reduce(%{}, fn {_, views}, acc1 ->
      Enum.reduce(views, acc1, fn {date, count}, acc2 ->
        Map.update(acc2, date, count, &(&1 + count))
      end)
    end)
    |> reduce_counts(range, period)
  end

  #
  # INTERNAL FUNCTIONS AND MODULES
  #

  defp request_page_views(nil), do: %{}

  defp request_page_views(request) do
    _ = Logger.debug(~s(REQUEST: #{inspect(request)}))

    request_body =
      Jason.encode!(%{
        reportRequests: [request]
      })

    result =
      with {:ok, token} <- Goth.fetch(Darth.Goth),
           headers <- add_auth_header(@http_headers, token.token),
           {:ok, resp} <- HTTPoison.post(url(), request_body, headers, @http_options),
           {:ok, resp_body} <- maybe_unpack(resp),
           {:ok, resp_json} <- Jason.decode(resp_body),
           do: {:ok, resp_json}

    case result do
      {:ok, resp} ->
        resp
        |> Map.get("reports", [])
        |> handle_request_results()

      err ->
        _ = Logger.error(~s(Couldn't fetch page views from Google Reporting API: #{inspect(err)}))
        %{}
    end
  end

  defp handle_request_results(nil), do: %{}

  defp handle_request_results(results) do
    Enum.reduce(results, %{}, fn res, acc1 ->
      rows = get_in(res, ["data", "rows"])

      if is_nil(rows) do
        acc1
      else
        Enum.reduce(rows, acc1, fn row, acc2 ->
          [url, day, month, year] = row["dimensions"]
          metric = List.first(row["metrics"])
          {count, _} = Integer.parse(List.first(metric["values"]))
          [_, project_id] = Regex.run(~r/\/projects\/(.*)\/publish/, url)
          date = Timex.parse!(~s(#{year}-#{month}-#{day}), "{YYYY}-{0M}-{0D}")

          acc2
          |> Map.put_new(project_id, %{})
          |> put_in([project_id, date], count)
        end)
      end
    end)
  end

  defp project_filters([]), do: []

  defp project_filters(project_ids) do
    filters =
      Enum.map(project_ids, fn id ->
        %{
          dimensionName: "ga:pagePath",
          expressions: [
            ~s(^/projects/#{id}/publish)
          ]
        }
      end)

    [%{filters: filters}]
  end

  @date_range_in_years 5
  defp report_date_ranges do
    now = Timex.now()

    [
      %{
        startDate: Timex.format!(Timex.shift(now, years: -1 * @date_range_in_years), "{YYYY}-{0M}-{0D}"),
        endDate: Timex.format!(Timex.shift(now, days: -1), "{YYYY}-{0M}-{0D}")
      }
    ]
  end

  defp report_request([], _), do: nil

  defp report_request(filters, date_ranges) do
    %{
      viewId: Application.get_env(:darth, :google_reporting_api_view_id, ""),
      dimensions: [
        %{
          name: "ga:pagePath"
        },
        %{
          name: "ga:day"
        },
        %{
          name: "ga:month"
        },
        %{
          name: "ga:year"
        }
      ],
      metrics: [
        %{
          expression: "ga:pageviews"
        }
      ],
      dimensionFilterClauses: filters,
      dateRanges: date_ranges
    }
  end

  @base_url "https://analyticsreporting.googleapis.com/v4/reports:batchGet"
  defp url do
    @base_url
  end

  defp add_auth_header(headers, token) do
    [{"Authorization", "Bearer #{token}"} | headers]
  end

  defp maybe_unpack(resp) do
    body =
      case List.keyfind(resp.headers, "Content-Encoding", 0) do
        {_, "gzip"} ->
          :zlib.gunzip(resp.body)

        {_, "deflate"} ->
          :zlib.unzip(resp.body)

        _ ->
          resp.body
      end

    {:ok, body}
  end

  defp reduce_counts(counts, range, period) do
    now = Timex.now()

    calc =
      Enum.reduce(counts, %{}, fn {date, count}, acc ->
        {:ok, key} = Statistics.period_key(period, date)
        Map.update(acc, key, count, &(&1 + count))
      end)

    Enum.map(Enum.reverse(0..(range - 1)), fn i ->
      {:ok, key} = Statistics.period_key(period, Statistics.shift_date(now, period, -1 * i))
      {key, Map.get(calc, key, 0)}
    end)
  end
end

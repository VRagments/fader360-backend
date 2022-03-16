defmodule Darth.Setup do
  @moduledoc false

  require Logger

  alias Ecto.{Migrator}
  alias Ecto.Adapters.{Postgres}
  alias Darth.{Repo}

  def download_user_agent_database do
    UAInspector.Downloader.download()
    UAInspector.reload()
    :ok
  end

  def update_log_dir(env) when env in [:stage, :prod, :stage_euromaxx] do
    log_root = Application.get_env(:darth, :log_root)
    {:ok, hostname} = :inet.gethostname()
    log_dir = '#{log_root}/#{hostname}'

    case File.mkdir_p(log_dir) do
      :ok ->
        :ok = Application.put_env(:lager, :log_root, log_dir)
        :ok = Application.stop(:lager)
        :ok = Application.start(:lager)
        Logger.info("Changed lager log dir to #{log_dir}")

      {:error, err} ->
        Logger.error("Couldn't change lager log dir to #{log_dir}: #{err}")
    end
  end

  def update_log_dir(_env), do: :ok

  def ensure_db do
    config = Application.get_env(:darth, Repo)

    case Postgres.storage_up(config) do
      :ok ->
        :ok

      {:error, reason} ->
        _ = Logger.error(~s(Error during db init: #{inspect(reason)}))
        :ok
    end
  end

  def load_seed_data(env) when env == :dev or env == :test do
    load_seed_data_file("dev_seeds.exs")
  end

  def load_seed_data(env) when env in [:stage, :prod, :stage_euromaxx] do
    load_seed_data_file("prod_seeds.exs")
  end

  def load_seed_data(env) do
    :io.format("No seed data to load for environment: ~p.~n", [env])
  end

  @start_apps [
    :crypto,
    :ssl,
    :logger,
    :lager,
    :logger_lager_backend,
    :postgrex,
    :ecto
  ]

  @app :darth

  def run_migrations(env) when env in [:dev, :test] do
    repos = Application.get_env(@app, :ecto_repos, [])
    Enum.each(repos, &run_migrations_for_repo/1)
  end

  def run_migrations(env) do
    :io.format("Migrations are not run automatically in production environment ~p.~n", [env])
  end

  # This function is used as a stand-alone task usable without the app running
  def migrate do
    IO.puts("Loading #{@app}..")
    _ = Application.load(@app)
    repos = Application.get_env(@app, :ecto_repos, [])

    IO.puts("Starting dependencies..")
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    IO.puts("Starting repos..")
    Enum.each(repos, &({:ok, _} = &1.start_link(pool_size: 1)))
    Enum.each(repos, &run_migrations_for_repo/1)

    IO.puts("Success!")
    :init.stop()
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp run_migrations_for_repo(repo) do
    app = Keyword.get(repo.config, :otp_app)
    dir = Path.join(repo_priv(repo), "migrations")
    IO.puts("Running ecto migrations for #{app}")
    Migrator.run(repo, dir, :up, all: true)
  end

  defp load_seed_data_file(file) do
    dir = repo_priv(Repo)
    filepath = Path.join(dir, file)

    _ =
      if File.regular?(filepath) do
        Code.require_file(file, dir)
      else
        :io.format("No seed data file for environment found: ~p.~n", [filepath])
      end

    :ok
  end

  defp repo_priv(repo) do
    config = repo.config()

    Application.app_dir(
      Keyword.fetch!(config, :otp_app),
      config[:priv] || "priv/#{repo |> Module.split() |> List.last() |> String.downcase()}"
    )
  end
end

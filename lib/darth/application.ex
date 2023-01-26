defmodule Darth.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Darth.Repo,
      DarthWeb.Telemetry,
      {Phoenix.PubSub, name: Darth.PubSub},
      DarthWeb.Endpoint,
      Darth.Scheduler,
      Darth.AssetProcessor,
      Darth.AssetProcessor.Downloader,
      Darth.AssetProcessor.PreviewDownloader
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Darth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DarthWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

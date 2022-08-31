# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :darth,
  ecto_repos: [Darth.Repo]

config :darth, Darth.Repo,
  migration_primary_key: [name: :id, type: :uuid],
  migration_foreign_key: [column: :id, type: :uuid]

# Configures the endpoint
config :darth, DarthWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: DarthWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Darth.PubSub,
  live_view: [signing_salt: "iMX9wAB3"]

config :guardian, Darth.Guardian,
  allowed_algos: ["HS512"],
  verify_module: Guardian.JWT,
  ttl: {1, :day},
  verify_issuer: true,
  permissions: %{
    default: [
      :read_profile,
      :write_profile,
      :read_token,
      :revoke_token
    ]
  }

config :guardian, Guardian.DB,
  repo: Darth.Repo,
  schema_name: "guardian_tokens",
  # default: 60 minutes
  sweep_interval: 60

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :darth, Darth.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.15.6",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ua_inspector,
  database_path: Path.join("/tmp", "darth_ua_inspector")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

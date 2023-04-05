# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :darth,
  ecto_repos: [Darth.Repo],
  asset_static_base_path: ["priv", "static", "media"],
  uploads_base_path: ["priv", "static", "uploads"],
  mv_asset_preview_download_path: ["priv", "static", "preview_download"]

config :darth, Darth.Repo,
  migration_primary_key: [name: :id, type: :uuid],
  migration_foreign_key: [column: :id, type: :uuid]

# Configures the endpoint
config :darth, DarthWeb.Endpoint,
  url: [host: "localhost", port: "45020"],
  render_errors: [view: DarthWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Darth.PubSub,
  live_view: [signing_salt: "iMX9wAB3"]

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

# configure Tailwind
config :tailwind,
  version: "3.1.8",
  default: [
    args: ~w(
    --config=tailwind.config.js
    --input=css/app.css
    --output=../priv/static/assets/app.css
  ),
    cd: Path.expand("../assets", __DIR__)
  ]

# App configurations
config :darth,
  default_mv_node: "https://dashboard.mediaverse.atc.gr/dam",
  upload_file_size: 80_000_000,
  default_project_scene_duration: "60",
  mv_asset_index_url: "/assets/paginated",
  mv_project_index_url: "/project/userList/all/paginated"

config :darth,
  reset_password_validity_in_days: 1,
  confirm_validity_in_days: 7,
  change_email_validity_in_days: 7,
  session_validity_in_days: 60,
  max_age_in_seconds: 60 * 60 * 24 * 60,
  remember_me_cookie: "_darth_web_user_remember_me",
  user_password_min_len: 10,
  mv_user_password_min_len: 6,
  user_password_max_len: 100

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason
config :phoenix_swagger, json_library: Jason

config :ua_inspector,
  database_path: Path.join("/tmp", "darth_ua_inspector")

config :darth, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: DarthWeb.Router,
      endpoint: DarthWeb.Endpoint
    ]
  }

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

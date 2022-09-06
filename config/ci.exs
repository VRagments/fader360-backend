import Config

config :darth, Darth.Repo,
  username: "postgres",
  database: "darth_ci",
  socket_dir: "/var/run/postgresql",
  pool: Ecto.Adapters.SQL.Sandbox

config :darth_web, DarthWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 45010],
  server: false,
  secret_key_base: "I1QJ3TVCktaCYnTO23zHXEi/iqqIj8ED1VNfpkaG4JU9QT0cPF9q2N4fditnKODm"

config :logger, level: :warn
config :logger, :console, format: "[$level] $message\n"

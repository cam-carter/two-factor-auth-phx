use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :two_factor_auth, TwoFactorAuthWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :two_factor_auth, TwoFactorAuth.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "two_factor_auth_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :two_factor_auth,
  ecto_repos: [TwoFactorAuth.Repo]

# Guardian config
config :two_factor_auth, TwoFactorAuth.Guardian,
  issuer: "two_factor_auth",
  secret_key: "fEDhCsDcIp+/+9Fyp0buoJfAvkIp5xmw6+K0iy6Vch5HzrMx+qCIMB72oJuCpyhD"

# Configures the endpoint
config :two_factor_auth, TwoFactorAuthWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "ywXmXRkSVFTK6uC/jByCSNPhpPp7L+rVWqXpTH86gymE1SC/mw08Q9hYI1/xQrmW",
  render_errors: [view: TwoFactorAuthWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: TwoFactorAuth.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

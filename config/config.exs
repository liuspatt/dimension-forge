# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dimension_forge,
  ecto_repos: [DimensionForge.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :dimension_forge, DimensionForgeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: DimensionForgeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DimensionForge.PubSub,
  live_view: [signing_salt: "Tv1MnF6e"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dimension_forge, DimensionForge.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Mogrify to use modern ImageMagick commands
config :mogrify, cli_options: [magick: "magick"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

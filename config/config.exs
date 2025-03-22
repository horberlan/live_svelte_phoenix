# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :live_svelte_pheonix, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10, email: 10],
  repo: LiveSveltePheonix.Repo

config :live_svelte_pheonix,
  ecto_repos: [LiveSveltePheonix.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :live_svelte_pheonix, LiveSveltePheonixWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: LiveSveltePheonix.PubSub,
  render_errors: [
    formats: [html: LiveSveltePheonixWeb.ErrorHTML, json: LiveSveltePheonixWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LiveSveltePheonix.PubSub,
  live_view: [signing_salt: "AJM5Yhxh"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :live_svelte_pheonix, LiveSveltePheonix.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
# config :esbuild,
#   version: "0.17.11",
#   live_svelte_pheonix: [
#     args:
#       ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
#     cd: Path.expand("../assets", __DIR__),
#     env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
#   ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  live_svelte_pheonix: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

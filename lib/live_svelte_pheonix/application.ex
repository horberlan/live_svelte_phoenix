defmodule LiveSveltePheonix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {NodeJS.Supervisor, [path: LiveSvelte.SSR.NodeJS.server_path(), pool_size: 4]},
      LiveSveltePheonixWeb.Telemetry,
      LiveSveltePheonix.Repo,
      {DNSCluster,
       query: Application.get_env(:live_svelte_pheonix, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:live_svelte_pheonix, Oban)},
      {Phoenix.PubSub, name: LiveSveltePheonix.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LiveSveltePheonix.Finch},
      # Start a worker by calling: LiveSveltePheonix.Worker.start_link(arg)
      # {LiveSveltePheonix.Worker, arg},
      # Start to serve requests, typically the last entry
      LiveSveltePheonixWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveSveltePheonix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveSveltePheonixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

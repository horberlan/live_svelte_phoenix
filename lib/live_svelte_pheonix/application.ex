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
      {Oban, Application.fetch_env!(:live_svelte_pheonix, Oban)},
      LiveSveltePheonix.Cache,
      {DNSCluster,
       query: Application.get_env(:live_svelte_pheonix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveSveltePheonix.PubSub},
      LiveSveltePheonixWeb.Presence,
      {Registry, keys: :unique, name: LiveSveltePheonix.DocumentRegistry},
      LiveSveltePheonix.DocumentSupervisor,
      {Finch, name: LiveSveltePheonix.Finch},
      LiveSveltePheonixWeb.Endpoint
    ]

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

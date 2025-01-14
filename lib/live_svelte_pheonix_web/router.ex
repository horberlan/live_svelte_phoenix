defmodule LiveSveltePheonixWeb.Router do
  use LiveSveltePheonixWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveSveltePheonixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveSveltePheonixWeb do
    pipe_through :browser

    # get "/", PageController, :home
    live "/", SvelteLive
    live "/session/:session_id", SessionLive
  end

  if Application.compile_env(:live_svelte_pheonix, :dev_routes) do
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveSveltePheonixWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

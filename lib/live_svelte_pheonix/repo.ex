defmodule LiveSveltePheonix.Repo do
  use Ecto.Repo,
    otp_app: :live_svelte_pheonix,
    adapter: Ecto.Adapters.Postgres
end

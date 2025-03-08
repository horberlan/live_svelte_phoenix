defmodule LiveSveltePheonix.Utils do
  import Phoenix.LiveView

  def push_session_storage(socket, method, params \\ []) do
    push_event(socket, "session-storage", %{
      method: method,
      params: List.wrap(params)
    })
  end
end

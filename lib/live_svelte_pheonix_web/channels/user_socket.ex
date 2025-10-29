defmodule LiveSveltePheonixWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "document:*", LiveSveltePheonixWeb.DocumentChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # Here you can validate the token and extract user_id
    # For simplicity, we'll just pass the token as user_id
    # In production, you should validate JWT token or similar
    {:ok, user_id} = verify_token(token)
    {:ok, assign(socket, :user_id, user_id)}
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  # Helper function to verify token
  # In production, use Phoenix.Token or similar
  defp verify_token(token) do
    # Here you would implement real token validation
    # For example: Phoenix.Token.verify(LiveSveltePheonixWeb.Endpoint, "user socket", token)
    {:ok, token}
  end
end

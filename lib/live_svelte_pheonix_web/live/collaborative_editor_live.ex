defmodule LiveSveltePheonixWeb.CollaborativeEditorLive do
  @moduledoc """
  Demo LiveView showcasing real-time collaborative editing.

  This page demonstrates the collaborative editor with:
  - Real-time synchronization using Delta OT
  - Automatic conflict resolution
  - Multiple simultaneous users
  - Cursor preservation during edits
  """
  use LiveSveltePheonixWeb, :live_view

  @default_content "<p>Start writing here...</p>"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_initial_state(socket)}
  end

  @impl true
  def handle_event("content_updated", %{"content" => content}, socket) do
    # Fallback: stores content locally
    # In production, you would persist to database
    {:noreply, assign(socket, :content, content)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="max-w-4xl mx-auto">
        <h1 class="text-3xl font-bold mb-2">Collaborative Editor</h1>
        <p class="text-gray-600 mb-6">
          Open this page in multiple tabs or share the link to test real-time collaboration!
        </p>

        <div class="bg-base-200 rounded-lg shadow-lg p-6">
          <.live_component
            module={LiveSvelte.Components}
            id="collaborative-editor"
            name="Editor"
            props={
              %{
                content: @content,
                docId: @doc_id,
                userId: @user_id,
                userName: @user_name,
                enableCollaboration: true
              }
            }
          />
        </div>

        <div class="mt-6 p-4 bg-blue-50 rounded-lg">
          <h3 class="font-semibold mb-2">Session Information:</h3>
          <ul class="text-sm space-y-1">
            <li><strong>Document ID:</strong> {@doc_id}</li>
            <li><strong>Your ID:</strong> {@user_id}</li>
            <li><strong>Your Name:</strong> {@user_name}</li>
          </ul>
        </div>

        <div class="mt-6 p-4 bg-gray-50 rounded-lg">
          <h3 class="font-semibold mb-2">How it works:</h3>
          <ul class="text-sm space-y-2 list-disc list-inside">
            <li>Changes are synchronized in real-time using Delta OT</li>
            <li>Conflicts are automatically resolved on the server</li>
            <li>You can see other active collaborators</li>
            <li>Change history is maintained for undo/redo</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # Private Functions

  defp assign_initial_state(socket) do
    socket
    |> assign(:doc_id, generate_document_id())
    |> assign(:user_id, generate_user_id())
    |> assign(:user_name, generate_user_name())
    |> assign(:content, @default_content)
  end

  defp generate_document_id, do: "doc-#{:rand.uniform(1000)}"
  defp generate_user_id, do: "user-#{:rand.uniform(10000)}"
  defp generate_user_name, do: "User #{:rand.uniform(100)}"
end

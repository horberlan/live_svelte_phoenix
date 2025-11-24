defmodule LiveSveltePheonixWeb.CollaborativeEditorLive do
  @moduledoc """
  LiveView for the collaborative editor, powered by Yjs.
  """
  use LiveSveltePheonixWeb, :live_view

  alias LiveSveltePheonix.DocumentSupervisor
  alias LiveSveltePheonix.CollaborativeDocument

  on_mount {LiveSveltePheonixWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(%{"doc_id" => doc_id}, _session, socket) do
    # Start the document GenServer if it's not already running
    DocumentSupervisor.start_document(doc_id)

    # Subscribe this LiveView to the document's updates
    CollaborativeDocument.subscribe(doc_id, self())

    socket =
      socket
      |> assign_defaults(doc_id, socket.assigns.current_user)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, redirect(socket, to: "/")}
  end

  @impl true
  def handle_event("yjs_provider_ready", %{"doc_id" => doc_id}, socket) do
    case CollaborativeDocument.get_all(doc_id) do
      {:ok, %{doc: doc, awareness: awareness}} ->
        push_event(socket, "yjs_initial_state", %{
          status: "ok",
          doc: doc,
          awareness: awareness
        })
      _ ->
        push_event(socket, "yjs_initial_state", %{status: "error"})
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("yjs_update", %{"doc_id" => doc_id, "payload" => payload}, socket) do
    with {:ok, update} <- Base.decode64(payload) do
      CollaborativeDocument.handle_update(doc_id, self(), update)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("awareness_update", %{"doc_id" => doc_id, "payload" => payload}, socket) do
    with {:ok, update} <- Base.decode64(payload) do
      CollaborativeDocument.handle_awareness_update(doc_id, self(), update)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({CollaborativeDocument, "yjs_update", payload}, socket) do
    push_event(socket, "yjs_update", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({CollaborativeDocument, "awareness_update", payload}, socket) do
    push_event(socket, "awareness_update", payload)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    CollaborativeDocument.unsubscribe(socket.assigns.doc_id, self())
    :ok
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
      </div>
    </div>
    """
  end

  defp assign_defaults(socket, doc_id, nil) do
    user_id = "user-#{:rand.uniform(10000)}"
    socket
    |> assign(
      doc_id: doc_id,
      user_id: user_id,
      user_name: user_id,
      content: ""
    )
  end

  defp assign_defaults(socket, doc_id, user) do
    socket
    |> assign(
      doc_id: doc_id,
      user_id: "user-#{user.id}",
      user_name: user.email,
      content: ""
    )
  end
end

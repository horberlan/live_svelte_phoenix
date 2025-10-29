defmodule LiveSveltePheonix.CollaborativeDocumentTest do
  use ExUnit.Case, async: true

  alias LiveSveltePheonix.{CollaborativeDocument, DocumentSupervisor}
  alias Delta.Op

  setup do
    doc_id = "test-doc-#{:rand.uniform(10000)}"
    {:ok, _pid} = DocumentSupervisor.start_document(doc_id)

    on_exit(fn ->
      DocumentSupervisor.stop_document(doc_id)
    end)

    {:ok, doc_id: doc_id}
  end

  describe "document initialization" do
    test "starts with empty content", %{doc_id: doc_id} do
      contents = CollaborativeDocument.get_contents(doc_id)
      assert contents == []
    end

    test "starts with version 0", %{doc_id: doc_id} do
      state = CollaborativeDocument.get_state(doc_id)
      assert state.version == 0
    end

    test "starts with no collaborators", %{doc_id: doc_id} do
      state = CollaborativeDocument.get_state(doc_id)
      assert state.collaborators == %{}
    end
  end

  describe "document updates" do
    test "applies simple insert", %{doc_id: doc_id} do
      change = [Op.insert("Hello")]

      {:ok, result} = CollaborativeDocument.update(doc_id, change, 0, "user1")

      assert result.version == 1
      assert result.contents == [%{"insert" => "Hello"}]
    end

    test "applies multiple changes in sequence", %{doc_id: doc_id} do
      # First change
      change1 = [Op.insert("Hello")]
      {:ok, result1} = CollaborativeDocument.update(doc_id, change1, 0, "user1")
      assert result1.version == 1

      # Second change
      change2 = [Op.retain(5), Op.insert(" World")]
      {:ok, result2} = CollaborativeDocument.update(doc_id, change2, 1, "user1")
      assert result2.version == 2
    end

    test "transforms conflicting changes", %{doc_id: doc_id} do
      # User1 inserts "Hello"
      change1 = [Op.insert("Hello")]
      {:ok, _} = CollaborativeDocument.update(doc_id, change1, 0, "user1")

      # User2 tries to insert "World" at version 0 (outdated)
      change2 = [Op.insert("World")]
      {:ok, result} = CollaborativeDocument.update(doc_id, change2, 0, "user2")

      # The change should be transformed
      assert result.version == 2
    end
  end

  describe "collaborators" do
    test "adds collaborator", %{doc_id: doc_id} do
      CollaborativeDocument.add_collaborator(doc_id, "user1", %{name: "Alice"})

      state = CollaborativeDocument.get_state(doc_id)
      assert Map.has_key?(state.collaborators, "user1")
      assert state.collaborators["user1"].name == "Alice"
    end

    test "removes collaborator", %{doc_id: doc_id} do
      CollaborativeDocument.add_collaborator(doc_id, "user1", %{name: "Alice"})
      CollaborativeDocument.remove_collaborator(doc_id, "user1")

      state = CollaborativeDocument.get_state(doc_id)
      refute Map.has_key?(state.collaborators, "user1")
    end

    test "updates cursor position", %{doc_id: doc_id} do
      CollaborativeDocument.add_collaborator(doc_id, "user1", %{name: "Alice"})
      CollaborativeDocument.update_cursor(doc_id, "user1", %{from: 0, to: 5})

      state = CollaborativeDocument.get_state(doc_id)
      assert state.collaborators["user1"].cursor_position == %{from: 0, to: 5}
    end
  end

  describe "history and undo" do
    test "tracks history", %{doc_id: doc_id} do
      change1 = [Op.insert("Hello")]
      change2 = [Op.retain(5), Op.insert(" World")]

      CollaborativeDocument.update(doc_id, change1, 0, "user1")
      CollaborativeDocument.update(doc_id, change2, 1, "user1")

      history = CollaborativeDocument.get_history(doc_id)
      assert length(history) == 3  # versions 2, 1, 0
    end

    test "undo reverts last change", %{doc_id: doc_id} do
      change = [Op.insert("Hello")]
      CollaborativeDocument.update(doc_id, change, 0, "user1")

      {:ok, contents} = CollaborativeDocument.undo(doc_id)
      assert contents == []
    end

    test "undo on empty document returns error", %{doc_id: doc_id} do
      assert {:error, :nothing_to_undo} = CollaborativeDocument.undo(doc_id)
    end

    test "multiple undos", %{doc_id: doc_id} do
      change1 = [Op.insert("Hello")]
      change2 = [Op.retain(5), Op.insert(" World")]

      CollaborativeDocument.update(doc_id, change1, 0, "user1")
      CollaborativeDocument.update(doc_id, change2, 1, "user1")

      {:ok, _} = CollaborativeDocument.undo(doc_id)
      {:ok, contents} = CollaborativeDocument.undo(doc_id)

      assert contents == []
    end
  end

  describe "concurrent editing" do
    test "handles concurrent inserts at different positions", %{doc_id: doc_id} do
      # Initial document: "Hello"
      initial = [Op.insert("Hello")]
      CollaborativeDocument.update(doc_id, initial, 0, "user1")

      # User2 inserts at the beginning (version 1)
      change2 = [Op.insert("A"), Op.retain(5)]
      {:ok, result2} = CollaborativeDocument.update(doc_id, change2, 1, "user2")

      # User3 inserts at the end (version 1, outdated)
      change3 = [Op.retain(5), Op.insert("B")]
      {:ok, result3} = CollaborativeDocument.update(doc_id, change3, 1, "user3")

      # Both changes should be applied
      assert result2.version == 2
      assert result3.version == 3
    end

    test "handles concurrent deletes", %{doc_id: doc_id} do
      # Initial document: "Hello World"
      initial = [Op.insert("Hello World")]
      CollaborativeDocument.update(doc_id, initial, 0, "user1")

      # User2 deletes "Hello " (version 1)
      change2 = [Op.delete(6), Op.retain(5)]
      {:ok, _} = CollaborativeDocument.update(doc_id, change2, 1, "user2")

      # User3 deletes " World" (version 1, outdated)
      change3 = [Op.retain(5), Op.delete(6)]
      {:ok, result3} = CollaborativeDocument.update(doc_id, change3, 1, "user3")

      # The transformation should resolve the conflict
      assert result3.version == 3
    end
  end

  describe "document state" do
    test "tracks last updated time", %{doc_id: doc_id} do
      state_before = CollaborativeDocument.get_state(doc_id)

      Process.sleep(10)

      change = [Op.insert("Hello")]
      CollaborativeDocument.update(doc_id, change, 0, "user1")

      state_after = CollaborativeDocument.get_state(doc_id)

      assert DateTime.compare(state_after.last_updated, state_before.last_updated) == :gt
    end

    test "maintains version consistency", %{doc_id: doc_id} do
      for i <- 1..10 do
        change = [Op.insert("#{i}")]
        {:ok, result} = CollaborativeDocument.update(doc_id, change, i - 1, "user1")
        assert result.version == i
      end

      state = CollaborativeDocument.get_state(doc_id)
      assert state.version == 10
    end
  end
end

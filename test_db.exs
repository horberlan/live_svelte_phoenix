#!/usr/bin/env elixir

# Script para verificar dados no banco
Mix.install([])

alias LiveSveltePheonix.{Repo, Session}

# Listar todas as sessões
sessions = Repo.all(Session)

IO.puts("\n=== Sessões no banco ===")
IO.puts("Total: #{length(sessions)}\n")

Enum.each(sessions, fn session ->
  IO.puts("Session ID: #{session.session_id}")
  IO.puts("  User ID: #{session.user_id}")
  IO.puts("  Content: #{String.slice(session.content || "", 0, 50)}...")
  IO.puts("  Ydoc: #{if session.ydoc, do: "#{byte_size(session.ydoc)} bytes", else: "nil"}")
  IO.puts("  Updated: #{session.updated_at}")
  IO.puts("")
end)

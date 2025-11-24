#!/usr/bin/env elixir

# Script para testar salvamento de cor de fundo

alias LiveSveltePheonix.{Repo, Session}

session_id = "test-color-debug"

IO.puts("\n=== Teste de Background Color ===\n")

# 1. Buscar ou criar sessão
session = case Repo.get_by(Session, session_id: session_id) do
  nil ->
    IO.puts("Criando nova sessão: #{session_id}")
    %Session{}
    |> Session.changeset(%{session_id: session_id, user_id: 1})
    |> Repo.insert!()

  existing ->
    IO.puts("Sessão existente encontrada: #{session_id}")
    existing
end

IO.puts("Cor atual: #{inspect(session.background_color)}")

# 2. Atualizar cor
new_color = "#ff0000"
IO.puts("\nAtualizando cor para: #{new_color}")

case Session.update_background_color(session_id, new_color) do
  {:ok, updated} ->
    IO.puts("✅ Cor atualizada com sucesso!")
    IO.puts("Nova cor: #{updated.background_color}")

  {:error, reason} ->
    IO.puts("❌ Erro ao atualizar: #{inspect(reason)}")
end

# 3. Verificar se salvou
IO.puts("\nVerificando no banco...")
reloaded = Repo.get_by(Session, session_id: session_id)
IO.puts("Cor no banco: #{inspect(reloaded.background_color)}")

# 4. Testar get_background_color
IO.puts("\nTestando get_background_color...")
color = Session.get_background_color(session_id)
IO.puts("Resultado: #{inspect(color)}")

if color == new_color do
  IO.puts("\n✅ TESTE PASSOU!")
else
  IO.puts("\n❌ TESTE FALHOU!")
  IO.puts("Esperado: #{new_color}")
  IO.puts("Recebido: #{inspect(color)}")
end

defmodule LiveSveltePheonix.Utils do
  import Phoenix.LiveView

  def push_session_storage(socket, method, params \\ []) do
    push_event(socket, "session-storage", %{
      method: method,
      params: List.wrap(params)
    })
  end

  def huminize_date(date) do
    Timex.shift(date, minutes: 0) |> Timex.format("{relative}", :relative)
  end

  def parse_first_tag_text(html) do
    {:ok, html_parsed} = Floki.parse_fragment(~s[#{html}])
    case List.first(html_parsed) do
      {_tag, _attrs, children} ->
        {:ok, children}
      _ ->
        {:error, :unexpected_element_type}
    end
  end

  @doc """
  Mantido por compatibilidade com código existente.

  Os dados já estão em UTF-8 correto quando vêm do banco de dados e do YJS.
  Não é necessário fazer nenhuma conversão ou "fix".

  Se você está vendo caracteres incorretos, o problema está na ORIGEM dos dados,
  não na leitura. Verifique:
  1. Como os dados estão sendo inseridos no editor (JavaScript/Tiptap)
  2. Se o navegador está enviando UTF-8 correto
  3. Se há alguma transformação intermediária corrompendo os dados
  """
  def fix_utf8_encoding(value), do: value
end

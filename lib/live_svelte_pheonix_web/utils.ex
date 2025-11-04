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
end

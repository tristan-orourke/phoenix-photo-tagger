defmodule PhotoTaggerWeb.HtmlHelpers do
  alias Phoenix.HTML

  def escape_html_id(str) do
    str |> String.replace(~r/\s/, "-") |> HTML.css_escape()
  end
end

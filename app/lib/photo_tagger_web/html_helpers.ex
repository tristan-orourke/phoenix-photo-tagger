defmodule PhotoTaggerWeb.HtmlHelpers do
  def escape_html_id(str) do
    str |> String.replace(~r/\s/, "-")
  end
end

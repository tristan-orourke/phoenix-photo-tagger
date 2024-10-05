defmodule PhotoTaggerWeb.PhotoHTML do
  use PhotoTaggerWeb, :html

  embed_templates "photo_html/*"

  @doc """
  Renders a photo form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def photo_form(assigns)
end

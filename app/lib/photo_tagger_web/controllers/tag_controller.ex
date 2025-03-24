defmodule PhotoTaggerWeb.TagController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Gallery

  def edit_tags(conn, _params) do
    tags = Gallery.list_tags()
    render(conn, :edit_tags, tags: tags)
  end

  def update(conn, %{"tag" => tag_name, "tag_updates" => tag_params}) do
    tag = Gallery.get_tag_by_name!(tag_name)
    {:ok, _tag} = Gallery.update_tag(tag, tag_params)

    conn
    |> put_flash(:info, "Tag updated successfully.")
    |> redirect(to: ~p"/edit-tags")
  end

  def delete(conn, %{"tag" => tag_name}) do
    tag = Gallery.get_tag_by_name!(tag_name)
    {:ok, _tag} = Gallery.delete_tag(tag)

    conn
    |> put_flash(:info, "Tag deleted successfully.")
    |> redirect(to: ~p"/edit-tags")
  end
end

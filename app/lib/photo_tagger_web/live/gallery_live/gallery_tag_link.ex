defmodule PhotoTaggerWeb.GalleryLive.GalleryTagLink do
  use PhotoTaggerWeb, :live_component

  alias PhotoTaggerWeb.GalleryLive.Util

  attr(:tag, :string, required: true)
  attr(:folder, :string, required: true)
  attr(:current_tags, :list, required: true)
  attr(:exclude_tags, :list, required: true)
  attr(:selected_photo_ids, :list, required: true)
  attr(:is_admin, :boolean, default: false)
  attr(:is_recommended, :boolean, default: false)
  attr(:is_selected, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <div>
      <%= if @is_recommended do %>
        <.toggle_link
          selected={@is_selected}
          href={@url}
        >
          {@tag}
        </.toggle_link>
      <% else %>
        <.link class="mr-2 my-1" patch={@url} >
          {@tag}
        </.link>
      <% end %>
    </div>
    """
  end

  def update(assigns, socket) do
    tags_list =
      case {assigns.is_recommended, assigns.tag in assigns.current_tags} do
        # This tag is in current_tags, so we toggle it off
        {_, true} ->
          Enum.filter(assigns.current_tags, &(&1 != assigns.tag))

        # This tag is not in current tags but compatible with them, so we toggle it on
        {true, false} ->
          assigns.current_tags ++ [assigns.tag]

        # This tag is not compatible with current tags, so we link straight to it
        _ ->
          [assigns.tag]
      end

    url =
      Util.build_url(
        assigns.folder,
        assigns.selected_photo_ids,
        tags_list,
        assigns.exclude_tags,
        assigns.is_admin
      )

    {:ok,
     socket
     |> assign(:url, url)
     |> assign(:is_recommended, assigns.is_recommended)
     |> assign(:is_selected, assigns.tag in assigns.current_tags)
     |> assign(:tag, assigns.tag)}
  end
end

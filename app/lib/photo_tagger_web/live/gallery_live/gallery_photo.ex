defmodule PhotoTaggerWeb.GalleryLive.GalleryPhoto do
  use PhotoTaggerWeb, :live_component
  alias PhotoTagger.Uploaders.ImageUploader

  attr(:photo, :map, required: true)
  attr(:is_selected, :boolean, default: false)
  attr(:collapse_groups, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <li class="aspect-square">
      <button
        id={"gallery-photo-button-#{@photo.id}"}
        class="h-full w-full relative block
          data-[selected]:outline
          outline-4 outline-offset-2 outline-blue-400
          phx-click-loading:outline phx-click-loading:outline-blue-200"
        data-selected={@is_selected}
        phx-click={if(@collapse_groups and @photo.group, do: "select_gallery_group", else: "select_gallery_photo")}
        phx-value-photo_id={@photo.id}
        phx-value-photo_group={@photo.group}
      >
        <%!-- use object-cover for cropped squares, and object-contain for shrinked full images --%>
        <img
          class="w-full h-full object-cover"
          alt={@photo.name}
          src={ImageUploader.url({@photo.image, @photo}, :small)}
        />
        <%= if @collapse_groups and @photo.group do %>
          <div class="w-full h-full -z-10 absolute left-1 bottom-1 bg-gray-500" />
          <div class="w-full h-full -z-20 absolute left-2 bottom-2 bg-gray-400" />
        <% end %>
      </button>
    </li>
    """
  end
end

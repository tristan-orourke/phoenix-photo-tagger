defmodule PhotoTaggerWeb.GalleryLive.GalleryPhoto do
  use PhotoTaggerWeb, :live_component
  alias PhotoTagger.Uploaders.ImageUploader

  attr(:photo_id, :string, required: true)
  attr(:photo_group, :string, default: nil)
  attr(:photo_name, :string, required: true)
  attr(:photo_image, :string, required: true)
  attr(:photo_folder, :string, required: true)
  attr(:is_selected, :boolean, default: false)
  attr(:collapse_groups, :boolean, default: false)
  attr(:is_admin, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <li class="aspect-square">
      <button
        id={"gallery-photo-button-#{@photo_id}"}
        class="relative block
          square-image
          data-[selected]:outline
          outline-4 outline-offset-2 outline-blue-400
          phx-click-loading:outline phx-click-loading:outline-blue-200"
        data-selected={@is_selected}
        phx-click={if(@collapse_groups and @photo_group != nil and @is_admin, do: "select_gallery_group", else: "select_gallery_photo")}
        phx-value-photo_id={@photo_id}
        phx-value-photo_group={@photo_group}
      >
        <%!-- use object-cover for cropped squares, and object-contain for shrinked full images --%>
        <img
          class="aspect-square object-cover"
          alt={@photo_name}
          src={@photo_image_url}
        />
        <%= if @collapse_groups and @photo_group do %>
          <div class="w-full h-full -z-10 absolute left-1 bottom-1 bg-gray-500" />
          <div class="w-full h-full -z-20 absolute left-2 bottom-2 bg-gray-400" />
        <% end %>
      </button>
    </li>
    """
  end

  def update(assigns, socket) do
    {:ok,
     assign(
       socket,
       :photo_image_url,
       ImageUploader.url({assigns.photo_image, %{folder: assigns.photo_folder}}, :small)
     )
     |> assign(
       Map.drop(assigns, [:photo_image, :photo_folder])
     )}
  end
end

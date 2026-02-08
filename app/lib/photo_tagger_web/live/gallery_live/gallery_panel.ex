defmodule PhotoTaggerWeb.GalleryLive.GalleryPanel do
  use PhotoTaggerWeb, :live_component

  attr(:photos, :list, required: true)
  # attr(:folder, :string, default: nil)
  attr(:selected_photo_ids, :list, default: [])
  attr(:collapse_groups, :boolean, default: false)
  attr(:zoom_level, :integer, default: 0)
  attr(:is_admin, :boolean, required: true)
  attr(:sort, :atom, default: :date)

  def render(assigns) do
    ~H"""
    <div class="p-2 lg:p-6 will-change-auto hover:will-change-scroll">
      <ul 
        class={"grid gap-2 lg:gap-4
        #{@grid_size}
        md:#{@md_grid_size}
        lg:#{@lg_grid_size}
        xl:#{@xl_grid_size}
        2xl:#{@_2xl_grid_size}"}
        id="gallery-grid"
        phx-hook={if @is_admin and @sort == :manual, do: "SortableHook", else: nil}
        data-sortable-enabled={@is_admin and @sort == :manual}
      >
        <%= for photo <- @photos do %>
          <.live_component
            module={PhotoTaggerWeb.GalleryLive.GalleryPhoto}
            id={photo.id}
            photo_id={photo.id}
            photo_group={photo.group}
            photo_name={photo.name}
            photo_image={photo.image}
            photo_folder={photo.folder}
            is_selected={photo.id in @selected_photo_ids}
            collapse_groups={@collapse_groups}
            is_admin={@is_admin}
          />
        <% end %>
      </ul>
    </div>
    """
  end

  def update(assigns, socket) do
    socket =
      case assigns.collapse_groups do
        false ->
          socket

        true ->
          grouped_photos = Enum.group_by(assigns.photos, & &1.group)

          assign(
            socket,
            :photos,
            # Filter out photos that are in a group, excepting the first in any group
            Enum.filter(assigns.photos, fn photo ->
              photo.group == nil or photo == List.first(grouped_photos[photo.group])
            end)
          )
      end



    socket =
      socket
      |> assign(:grid_size, get_grid_size(assigns.zoom_level, 1))
      |> assign(:md_grid_size, get_grid_size(assigns.zoom_level, 2))
      |> assign(:lg_grid_size, get_grid_size(assigns.zoom_level, 4))
      |> assign(:xl_grid_size, get_grid_size(assigns.zoom_level, 4))
      |> assign(:_2xl_grid_size, get_grid_size(assigns.zoom_level, 6))

    {:ok,
     socket
     |> assign(:selected_photo_ids, assigns.selected_photo_ids)
     |> assign(:photos, assigns.photos)
     |> assign(:collapse_groups, assigns.collapse_groups)
     |> assign(:is_admin, assigns.is_admin)}
  end

  def clamp(x, min, max), do: min(max(x, min), max)

  def get_grid_size(zoom_level, base_size) do
    size = clamp(base_size - zoom_level, 1, 9)
    "grid-cols-#{size}"
  end
end

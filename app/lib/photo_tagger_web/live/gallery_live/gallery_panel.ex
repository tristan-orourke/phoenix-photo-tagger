defmodule PhotoTaggerWeb.GalleryLive.GalleryPanel do
  use PhotoTaggerWeb, :live_component
  require Logger

  attr(:photos, :list, required: true)
  # attr(:folder, :string, default: nil)
  attr(:selected_photo_ids, :list, default: [])
  attr(:collapse_groups, :boolean, default: false)
  attr(:zoom_level, :integer, default: 0)
  attr(:is_admin, :boolean, required: true)

  def render(assigns) do
    Logger.debug("Rendering GalleryPanel with assigns: #{inspect(Map.keys(assigns.__changed__))}")
    ~H"""
    <div class="p-2 lg:p-6 ">
      <ul
        id="photos-infinite-scroll"
        phx-viewport-bottom={!@end_of_timeline? && "next-page"}
        phx-target={@myself}
        phx-page-loading
        class={[
          "grid gap-2 lg:gap-4",
          "#{get_grid_size(@zoom_level, 1)}",
          "md:#{get_grid_size(@zoom_level, 2)}",
          "lg:#{get_grid_size(@zoom_level, 4)}",
          "xl:#{get_grid_size(@zoom_level, 4)}",
          "2xl:#{get_grid_size(@zoom_level, 6)}"
        ]}
      >
        <%= for photo <- Enum.take(@photos, @page * @per_page) do %>
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
      <%= if not @end_of_timeline? do %>
        <div
          id="load-more"
          class="flex justify-center items-center w-full p-10"
        >
          <.icon name="hero-arrow-path" class="w-10 h-10 animate-spin"/>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     socket
     |> assign(page: 1, per_page: 30, end_of_timeline?: false)}
  end

  def update(assigns, socket) do
    socket =
      case assigns.collapse_groups do
        false ->
          assign(socket, :photos, assigns.photos)

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
      # |> assign(:grid_size, get_grid_size(assigns.zoom_level, 1))
      # |> assign(:md_grid_size, get_grid_size(assigns.zoom_level, 2))
      # |> assign(:lg_grid_size, get_grid_size(assigns.zoom_level, 4))
      # |> assign(:xl_grid_size, get_grid_size(assigns.zoom_level, 4))
      # |> assign(:_2xl_grid_size, get_grid_size(assigns.zoom_level, 6))

    {:ok,
     socket
     |> assign(:selected_photo_ids, assigns.selected_photo_ids)
     |> assign(:photos, assigns.photos)
     #  |> then(fn socket ->
     #    case socket.assigns.photos do
     #      nil -> paginate_photos(socket, 1) # We only want to do this in handle_params the first time
     #      _ -> socket
     #    end
     #  end)
     |> assign(:collapse_groups, assigns.collapse_groups)
     |> assign(:is_admin, assigns.is_admin)}
  end

  def clamp(x, min, max), do: min(max(x, min), max)

  def get_grid_size(zoom_level, base_size) do
    size = clamp(base_size - zoom_level, 1, 9)
    Logger.debug("Zoom level being calculated")
    "grid-cols-#{size}"
  end

  def handle_event("next-page", _, socket) do
    new_page = socket.assigns.page + 1
    finished = new_page * socket.assigns.per_page >= Enum.count(socket.assigns.photos)

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:end_of_timeline?, finished)}
  end
end

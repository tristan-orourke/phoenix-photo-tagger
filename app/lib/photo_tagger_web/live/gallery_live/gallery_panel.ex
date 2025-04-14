defmodule PhotoTaggerWeb.GalleryLive.GalleryPanel do
  use PhotoTaggerWeb, :live_component

  attr(:photos, :list, required: true)
  # attr(:folder, :string, default: nil)
  attr(:selected_photo_ids, :list, default: [])
  attr(:collapse_groups, :boolean, default: false)
  attr(:zoom_level, :integer, default: 0)
  attr(:is_admin, :boolean, required: true)

  def render(assigns) do
    ~H"""
    <div class="p-2 lg:p-6 ">
      <ul
        id="photos-infinite-scroll"
        phx-update="stream"
        phx-viewport-top={@page > 1 && "prev-page"}
        phx-viewport-bottom={!@end_of_timeline? && "next-page"}
        phx-target={@myself}
        phx-page-loading
        class={[
          "grid gap-2 lg:gap-4",
          "#{@grid_size}",
          "md:#{@md_grid_size}",
          "lg:#{@lg_grid_size}",
          "xl:#{@xl_grid_size}",
          "2xl:#{@_2xl_grid_size}",
          if(@end_of_timeline?, do: "pb-10", else: "pb-[calc(200vh)]"),
          if(@page == 1, do: "pt-10", else: "pt-[calc(200vh)]")
        ]}
      >
        <%= for {id, photo} <- @streams.photos do %>
          <.live_component
            module={PhotoTaggerWeb.GalleryLive.GalleryPhoto}
            id={id}
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
      <div id="infinite-scroll-marker" phx-hook="InfiniteScroll" data-page={@page}></div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket
      |> assign(page: 1, per_page: 20)
      |> assign(photos: nil)
    }
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
     |> assign(:all_photos, assigns.photos)
     |> then(fn socket ->
       case socket.assigns.photos do
         nil -> paginate_photos(socket, 1) # We only want to do this in handle_params the first time
         _ -> socket
       end
     end)
     |> assign(:collapse_groups, assigns.collapse_groups)
     |> assign(:is_admin, assigns.is_admin)}
  end

  def clamp(x, min, max), do: min(max(x, min), max)

  def get_grid_size(zoom_level, base_size) do
    size = clamp(base_size - zoom_level, 1, 9)
    "grid-cols-#{size}"
  end


  defp paginate_photos(socket, new_page) when new_page >= 1 do
    %{per_page: per_page, page: cur_page} = socket.assigns
    photos = Enum.slice(socket.assigns.all_photos, ((new_page - 1) * per_page)..(new_page * per_page - 1))

    {photos, at, limit} =
      if new_page >= cur_page do
        {photos, -1, per_page * 3 * -1}
      else
        {Enum.reverse(photos), 0, per_page * 3}
      end

    case photos do
      [] ->
        assign(socket, end_of_timeline?: at == -1)

      [_ | _] = photos ->
        socket
        |> assign(end_of_timeline?: false)
        |> assign(:page, new_page)
        |> stream(:photos, photos, at: at, limit: limit)
    end
  end

  def handle_event("next-page", _, socket) do
    {:noreply, paginate_photos(socket, socket.assigns.page + 1)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, paginate_photos(socket, 1)}
  end

  def handle_event("prev-page", _, socket) do
    if socket.assigns.page > 1 do
      {:noreply, paginate_photos(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
  end
end

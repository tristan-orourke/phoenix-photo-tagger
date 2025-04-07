defmodule PhotoTaggerWeb.GalleryLive.PublicGallery do
  use PhotoTaggerWeb, :live_view

  alias PhotoTagger.Gallery
  alias PhotoTagger.Repo

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 md:grid-cols-3 h-full">
      <div id="gallery-section md:col-span-2 overflow-y-auto">
        <%!-- <.gallery
          photos={@filtered_photos}
          folder={@folder}
          selected_photo_ids={@selected_photo_ids}
          collapse_groups={@collapse_groups}
          zoom_level={@zoom_level}
        /> --%>
        Gallery
      </div>
      <div id="photo-section" class="overflow-y-auto">
        <%!-- <.photo
          photo={@selected_photo}
          folder={@folder}
          tags={@tags}
          all_tags={@all_tags}
          update_photo_form={@update_photo_form}
        /> --%>
        Photo
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _session, socket) do
    folder = Map.get(params, "folder")
    tags = Map.get(params, "query_tags", [])
    photo_id = Map.get(params, "photo_id", nil)

    filtered_photos =
      case {folder, tags} do
        {nil, []} ->
          Gallery.list_photos()

        {nil, tags} ->
          Gallery.list_photos_by_all_tags(tags)

        {folder, []} ->
          Gallery.list_photos_by_folder(folder)

        {folder, tags} ->
          Gallery.list_photos_by_folder_and_tags(folder, tags)
      end

    selected_photo = case photo_id do
      nil -> nil
      _ -> Gallery.get_photo!(photo_id) |> Repo.preload(:tags)
    end

    # Reset scroll position of a section if the relevent params change
    socket =
      if(both_nil_or_same_id?(selected_photo, Map.get(socket.assigns, :selected_photo)),
        do: push_event(socket, "scroll_to_top", %{selector: "#photo-section"}),
        else: socket
      )

    socket =
      if(
        folder != Map.get(socket.assigns, :folder) or
          Enum.sort(tags) != Enum.sort(Map.get(socket.assigns, :tags, [])),
        do: push_event(socket, "scroll_to_top", %{selector: "#gallery-section"}),
        else: socket
      )

    {:noreply, socket
        |> assign(:folder, folder)
        |> assign(:tags, tags)
        |> assign(:filtered_photos, filtered_photos)
        |> assign(:selected_photo, selected_photo)
    }
  end

  ## Utility functions
  def both_nil_or_same_id?(a, b) do
    case {a, b} do
      {nil, nil} -> true
      {%{id: id1}, %{id: id2}} -> id1 == id2
      _ -> false
    end
  end

end

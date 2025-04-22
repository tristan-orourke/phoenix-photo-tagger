defmodule PhotoTaggerWeb.GalleryLive.Drift do
  use PhotoTaggerWeb, :live_view
  require Logger

  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.WeightedList
  alias PhotoTagger.Uploaders.ImageUploader

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 overflow-y-auto w-screen h-screen flex items-center justify-center bg-zinc-800">
      <img
        class="object-contain w-full max-w-full lg:max-h-full"
        alt={@photo.name}
        src={ImageUploader.url({@photo.image, @photo}, :original)}
      />
      <div class="absolute top-4 left-4 text-sm">
        <ul>
          <li :for={tag <- @photo.tags} class="shadow-zinc-700/10 ring-zinc-800 shadow-2xl bg-white ring-1 rounded-full px-1 my-1 w-min text-sm">
            #{tag.name}
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(5 * 1000, self(), :switch_photos)

    {:ok, socket}
  end

  def handle_params(params, _session, socket) do
    folder = Map.get(params, "folder", nil)
    {:ok, photo_id} = Map.fetch(params, "photo_id")

    photo = Gallery.get_photo!(String.to_integer(photo_id)) |> Repo.preload(:tags)

    {:noreply, socket |> assign(:photo, photo) |> assign(:folder, folder)}
  end

  def handle_info(:switch_photos, socket) do
    # Get the current photo and folder from the socket
    photo = socket.assigns.photo
    folder = socket.assigns.folder

    # Pick a new photo based on the current one
    new_photo = pick_next_photo(photo, folder)

    # Save the new photo
    {:noreply, socket |> assign(:photo, new_photo)}
  end

  # NOTE: this is an expensive operation, and should be done in a background job
  def pick_next_photo(photo, folder) do
    # Get all photos in our selection, excluding the current one
    photos =
      case folder do
        nil -> Gallery.list_photos()
        folder -> Gallery.list_photos_by_folder(folder)
      end
      |> Enum.reject(&(&1.id == photo.id))
      |> Repo.preload(:tags)

    # Get the similarity scores for each photo, and build a weighted list
    weighted_list =
      photos
      |> Enum.map(fn p -> {p, similarity_score(photo, p)} end)
      |> WeightedList.new()

    # Sample a photo from the weighted list
    WeightedList.sample(weighted_list)
  end

  # One point for sharing the same folder. One point for each tag in common.
  def similarity_score(photo1, photo2) do
    folder_score = if photo1.folder == photo2.folder, do: 1, else: 0

    tags1 = Enum.map(photo1.tags, & &1.id)
    tags2 = Enum.map(photo2.tags, & &1.id)
    tag_score =
      tags1
      |> Enum.filter(&(&1 in tags2))
      |> length()

    folder_score + tag_score
  end
end

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
          <li :for={tag <- @tags} class={case {tag in @photo_tags, tag in @prev_photo_tags} do
              {true, true} -> "h-6"
              {true, false} -> "h-6 new-tag"
              {false, true} -> "h-6 old-tag"
              {false, false} -> "h-6"
            end}
            id={"tag-#{tag}"}
            data-hide={
              #JS.add_class("opacity-0", to: "#tag-#{tag} > p")
            JS.transition({"transition-all transform ease-out duration-1000",
                "h-6 opacity-100",
                "h-0 opacity-0"},
              to: "#tag-#{tag}",
              time: 1000,

            )}
            data-show={JS.transition(
                {"transition-all transform ease-out duration-1000",
                "h-0 opacity-0",
                "h-6 opacity-100"},
              to: "#tag-#{tag}",
              time: 1000
            )}
          >
            <p class="data-[attention]:ring-2 ring-cyan-400 ring-offset-1 ring-offset-zinc-800
              bg-white data-[attention]:bg-cyan-100 rounded-full px-1 w-min text-sm"
              data-attention={tag == @focus_tag}
            >
              #{tag}
            </p>
          </li>
        </ul>
      </div>
      <div class="absolute top-4 right-4 text-sm">
        <.button
          phx-click="increase_tempo"
        >
          <.icon name="hero-clock" class="w-5 h-5" />
          {case @interval_ms do
            1000 -> "1s"
            5000 -> "5s"
            10000 -> "10s"
            15000 -> "15s"
            _ -> ""
          end}
        </.button>
        <.button phx-click="switch_photos">
          <.icon name="hero-arrow-right-circle" class="w-5 h-5" />
        </.button>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    interval_ms = 5 * 1000

    {:ok, socket |> start_timer(interval_ms) |> assign(:prev_photo_tags, [])}
  end

  def handle_params(params, _session, socket) do
    folder = Map.get(params, "folder", nil)

    {:ok, photo_id} = Map.fetch(params, "photo_id")
    photo = Gallery.get_photo!(String.to_integer(photo_id)) |> Repo.preload(:tags)

    socket =
      if Map.has_key?(params, "tempo") and params["tempo"] != socket.assigns.interval_ms do
        socket |> start_timer(String.to_integer(params["tempo"]))
      else
        socket
      end

    photo_tags = Enum.map(photo.tags, & &1.name)

    tags =
      (photo_tags ++ socket.assigns.prev_photo_tags)
      |> Enum.uniq()
      |> Enum.sort()

    focus_tag =
      case Enum.empty?(photo_tags) do
        true -> nil
        false -> Enum.random(photo_tags)
      end

    {:noreply,
     socket
     |> assign(:photo, photo)
     |> assign(:folder, folder)
     |> assign(:tags, tags)
     |> assign(:photo_tags, photo_tags)
     |> assign(:focus_tag, focus_tag)
     |> push_event("show", %{selector: ".new-tag"})}
  end

  def start_timer(socket, interval_ms) do
    if Map.get(socket.assigns, :timer_ref) != nil do
      {:ok, _} = :timer.cancel(socket.assigns.timer_ref)
    end

    {:ok, timer_ref} =
      case connected?(socket) do
        true -> :timer.send_interval(interval_ms, self(), :switch_photos)
        false -> {:ok, nil}
      end

    assign(socket, :timer_ref, timer_ref) |> assign(:interval_ms, interval_ms)
  end

  def handle_info(:switch_photos, socket) do
    switch_photos(socket)
  end

  def handle_event("switch_photos", _, socket) do
    switch_photos(socket)
  end

  def switch_photos(socket) do
    # Get the current photo and folder from the socket
    photo = socket.assigns.photo
    folder = socket.assigns.folder
    focus_tag = socket.assigns.focus_tag

    # Pick a new photo based on the current one
    new_photo = pick_next_photo(photo, folder, focus_tag)
    new_photo_tags = Enum.map(new_photo.tags, & &1.name)

    tags =
      (new_photo_tags ++ socket.assigns.photo_tags)
      |> Enum.uniq()
      |> Enum.sort()

    focus_tag =
      case {focus_tag in new_photo_tags, Enum.empty?(new_photo_tags)} do
        {true, _} -> focus_tag # keep the same focus tag if possible
        {false, false} -> Enum.random(new_photo_tags) # otherwise pick a new one
        {false, true} -> nil # or lose focus if nothing to focus on
      end

    # Save the new photo
    {:noreply,
     socket
     |> assign(:prev_photo_tags, socket.assigns.photo_tags)
     |> assign(:photo, new_photo)
     |> assign(:photo_tags, new_photo_tags)
     |> assign(:tags, tags)
     |> assign(:focus_tag, focus_tag)
     |> push_event("show", %{selector: ".new-tag"})
     |> push_event("hide", %{selector: ".old-tag"})}
  end

  # NOTE: this is an expensive operation, and should be done in a background job
  def pick_next_photo(photo, folder, focus) do
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
      |> Enum.map(fn p -> {p, similarity_score(photo, p, focus)} end)
      |> WeightedList.new()

    # Sample a photo from the weighted list
    WeightedList.sample(weighted_list)
  end

  # One point for sharing the same folder. One point for each tag in common.
  def similarity_score(photo1, photo2, focus_tag \\ nil) do
    folder_score = if photo1.folder == photo2.folder, do: 1, else: 0

    tags1 = Enum.map(photo1.tags, & &1.id)
    tags2 = Enum.map(photo2.tags, & &1.id)

    tag_score =
      tags1
      |> Enum.filter(&(&1 in tags2))
      |> length()

    focus_score =
      if focus_tag != nil and focus_tag in tags1 and focus_tag in tags2 do
        1
      else
        0
      end

    1 + folder_score * 5 + tag_score * 10 + focus_score * 200
  end

  def handle_event("increase_tempo", _, socket) do
    new_interval_ms =
      case socket.assigns.interval_ms do
        1000 -> 5000
        5000 -> 10000
        10000 -> 15000
        15000 -> 1000
        _ -> 5000
      end

    {:noreply, socket |> start_timer(new_interval_ms)}
  end
end

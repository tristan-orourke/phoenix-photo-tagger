defmodule PhotoTaggerWeb.GalleryLive.Drift do
  use PhotoTaggerWeb, :live_view
  require Logger

  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.WeightedList
  alias PhotoTagger.Uploaders.ImageUploader

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 overflow-hidden w-screen h-screen flex items-center justify-center bg-zinc-800">
      <img
        class="object-contain w-full h-full max-w-full max-h-full"
        alt={@photo.name}
        src={ImageUploader.url({@photo.image, @photo}, :original)}
      />
      <div class="absolute top-4 left-4 text-sm">
        <ul>
          <li :for={tag <- @tags} class={case {tag in @photo_tags, tag in @prev_photo_tags} do
              {true, true} -> "shared-tag"
              {true, false} -> "new-tag"
              {false, true} -> "old-tag"
              {false, false} -> "h-0"
            end}
            id={"tag-#{tag}"}
            data-hide={
              JS.transition({"transition-all transform ease-in duration-1000",
                "h-6 opacity-100",
                "h-0 opacity-0"},
              to: "#tag-#{tag}",
              time: 1000
            )}
            data-show={JS.transition(
                {"transition-all transform ease-in duration-1000",
                "h-0 opacity-0",
                "h-6 opacity-100"},
              to: "#tag-#{tag}",
              time: 1000
            )}
          >
            <%
              is_shared = tag in @photo_tags and tag in @prev_photo_tags
              is_focus = tag == @focus_tag
              bg_class = cond do
                is_shared -> "bg-green-50"
                is_focus -> "bg-cyan-100"
                true -> "bg-white"
              end
              ring_class = cond do
                is_focus -> "ring-2 ring-cyan-400 ring-offset-1 ring-offset-zinc-800"
                is_shared -> "ring-1 ring-green-400 ring-offset-1 ring-offset-zinc-800"
                true -> ""
              end
            %>
            <p class={"rounded-full px-1 w-max text-sm transition-all duration-300 #{bg_class} #{ring_class}"}
              data-attention{is_focus}
              data-shared={is_shared}
              id={"tag-p-#{tag}"}
            >
              #{tag}
            </p>
          </li>
        </ul>
      </div>
      <div class="absolute top-4 right-4 text-sm flex items-center gap-2">
        <div
          id="countdown-timer"
          phx-hook="CountdownTimer"
          data-interval-ms={@interval_ms}
          data-timer-start-time={@timer_start_time}
          class="relative w-12 h-12"
        >
          <svg class="w-12 h-12 transform -rotate-90" viewBox="0 0 36 36">
            <circle
              cx="18"
              cy="18"
              r="16"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              class="text-zinc-600 opacity-20"
            />
            <g transform="translate(18, 18) scale(1, -1) translate(-18, -18)">
              <circle
                id="progress-circle"
                cx="18"
                cy="18"
                r="16"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-dasharray="100.53"
                stroke-dashoffset="0"
                class="text-white transition-all duration-100"
                stroke-linecap="round"
              />
            </g>
          </svg>
          <div class="absolute inset-0 flex items-center justify-center">
            <span id="countdown-seconds" class="text-white text-xs font-semibold">0</span>
          </div>
        </div>
        <.button
          phx-click="increase_tempo"
        >
          <.icon name="hero-clock" class="w-5 h-5" />
          {case @interval_ms do
            2000 -> "2s"
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

    {:ok,
     socket
     |> start_timer(interval_ms)
     |> assign(:prev_photo_tags, [])}
  end

  def handle_params(params, _session, socket) do
    folder = Map.get(params, "folder", nil)

    {:ok, photo_id} = Map.fetch(params, "photo_id")
    photo = Gallery.get_photo!(String.to_integer(photo_id)) |> Repo.preload(:tags)

    socket =
      if Map.has_key?(params, "tempo") and params["tempo"] != socket.assigns.interval_ms do
        socket |> start_timer(String.to_integer(params["tempo"]))
      else
        # Ensure timer_start_time is set even if timer doesn't change
        socket
        |> assign(
          :timer_start_time,
          Map.get(socket.assigns, :timer_start_time, System.system_time(:millisecond))
        )
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

    timer_start_time = System.system_time(:millisecond)

    assign(socket, :timer_ref, timer_ref)
    |> assign(:interval_ms, interval_ms)
    |> assign(:timer_start_time, timer_start_time)
  end

  def handle_info(:switch_photos, socket) do
    switch_photos(socket)
  end

  def handle_event("switch_photos", _, socket) do
    socket
    |> start_timer(socket.assigns.interval_ms)
    |> switch_photos()
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
        # keep the same focus tag if possible
        {true, _} -> focus_tag
        # otherwise pick a new one
        {false, false} -> Enum.random(new_photo_tags)
        # or lose focus if nothing to focus on
        {false, true} -> nil
      end

    # Reset timer start time when photos switch
    timer_start_time = System.system_time(:millisecond)

    # Save the new photo
    {:noreply,
     socket
     |> assign(:prev_photo_tags, socket.assigns.photo_tags)
     |> assign(:photo, new_photo)
     |> assign(:photo_tags, new_photo_tags)
     |> assign(:tags, tags)
     |> assign(:focus_tag, focus_tag)
     |> assign(:timer_start_time, timer_start_time)
     |> push_event("show", %{selector: ".new-tag"})
     |> push_event("hide", %{selector: ".old-tag"})
     |> push_event("highlight_shared", %{selector: ".shared-tag"})}
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

    if photos == [] do
      # If there are no other options, we must keep the same photo
      photo
    else
      # Get the similarity scores for each photo, and build a weighted list
      weighted_list =
        photos
        |> Enum.map(fn p -> {p, similarity_score(photo, p, focus)} end)
        |> WeightedList.new()

      # Sample a photo from the weighted list
      WeightedList.sample(weighted_list)
    end
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
        2000 -> 5000
        5000 -> 10000
        10000 -> 15000
        15000 -> 2000
        _ -> 5000
      end

    {:noreply, socket |> start_timer(new_interval_ms)}
  end
end

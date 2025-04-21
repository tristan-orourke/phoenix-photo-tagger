defmodule PhotoTaggerWeb.GalleryLive.NavPanel do
  use PhotoTaggerWeb, :live_component
  require Logger

  attr(:folder, :string, required: true)
  attr(:all_folders, :list, required: true)
  attr(:nav_tags, :list, required: true)
  attr(:recommended_tags, :list, required: true)
  attr(:current_tags, :list, required: true)
  # attr(:selected_photo_ids, :list, default: [])
  attr(:is_admin, :boolean, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <%= if not @is_open do %>
        <.button
          phx-click="toggle_nav_panel"
          phx-target={@myself}
        >
          <.icon name="hero-chevron-right" class="w-5 h-5" />
        </.button>
      <% else %>
        <div :if={@is_admin} class="relative">
          <.button
            phx-click="toggle_nav_panel"
            phx-target={@myself}
            class="absolute top-0 right-0"
          >
            <.icon name="hero-chevron-left" class="w-5 h-5" />
          </.button>
        </div>
        <h2 class="pt-4">Folders</h2>
        <form class="my-2" phx-change="change_folder">
          <select value={@folder} name="folder" id="folder-select"  class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm">
            <option value="">All folders</option>
            <%= for folder <- @all_folders do %>
              <option value={folder} selected={@folder == folder}>
                {folder}
              </option>
            <% end %>
          </select>
        </form>
        <h2 class="">Tags</h2>
        <nav class="my-2 pl-2 list-none">
          <%= if not Enum.empty?(@current_tags) do %>
            <h3 class="text-sm font-bold">Current tags</h3>
            <ul class="my-2">
              <%= for tag <- @current_tags do %>
                <li class="mr-2">
                  <.toggle_button
                    selected={true}
                    phx-click="toggle_tag"
                    phx-value-tag={tag}
                  >
                    {tag}
                  </.toggle_button>
                </li>
              <% end %>
            </ul>
          <% end %>
          <%= if not Enum.empty?(@recommended_nav_tags)
            and (@max_recommended_tags < 0
            or Enum.count(@recommended_nav_tags) <= @max_recommended_tags)
          do %>
            <h3 class="text-sm font-bold">Recommended tags</h3>
            <ul class="my-2">
              <%= for tag <- @recommended_nav_tags do %>
                <li class="mr-2">
                  <.toggle_button
                    selected={tag in @current_tags}
                    phx-click="toggle_tag"
                    phx-value-tag={tag}
                  >
                    {tag}
                  </.toggle_button>
                </li>
              <% end %>
            </ul>
          <% end %>
          <h3 class="text-sm font-bold">All tags</h3>
          <ul id="index-selectors" class="flex flex-wrap my-2 sticky top-0">
            <%= for {index, tags} <- Enum.sort(@indexed_tags) do %>
              <li>
                <%= if Enum.empty?(tags) do %>
                  {index}
                <% else %>
                  <button
                    phx-click="select_index"
                    phx-value-index={index}
                    phx-target={@myself}
                    class="underline text-blue-600 hover:text-blue-800 mr-2 aria-selected:font-bold"
                    aria-selected={if(@selected_index == index, do: "true", else: "false")}
                  >
                    {index}
                  </button>
                <% end %>
              </li>
            <% end %>
          </ul>
          <ul class="pb-96">
            <%= if @selected_index != nil do %>
              <%= for tag <- Map.get(@indexed_tags, @selected_index) do %>
                <%= if tag in @current_tags or tag in @recommended_nav_tags do %>
                  <li class="mr-2 content-visible-auto">
                    <.toggle_button
                      selected={tag in @current_tags}
                      phx-click="toggle_tag"
                      phx-value-tag={tag}
                    >
                      {tag}
                    </.toggle_button>
                  </li>
                <% else %>
                  <li class="mr-2 content-visible-auto">
                    <button
                      class="underline text-blue-600 hover:text-blue-800 mr-2"
                      phx-click="link_tag"
                      phx-value-tag={tag}
                    >
                      {tag}
                    </button>
                  </li>
                <% end %>
              <% end %>
            <% end %>
          </ul>
        </nav>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket |> assign(:is_open, true) |> assign(:selected_index, nil)}
  end

  def update(assigns, socket) do
    Logger.debug("NavPanel update: #{inspect(assigns)}")

    # We're going to show current tags seperately from recommended tags
    recommended_nav_tags =
      Enum.filter(assigns.recommended_tags, fn tag ->
        tag not in assigns.current_tags
      end)

    indexed_tags =
      Enum.group_by(assigns.nav_tags, fn tag ->
        char = String.at(tag, 0) |> remove_diacritics() |> String.upcase()

        if Regex.match?(~r/[A-Z]/, char) do
          char
        else
          "#"
        end
      end)

    index = case assigns.folder != Map.get(socket.assigns, :folder, nil) do
        true ->
          # if the folder changed, we need to reset the selected index
          nil

        false ->
          socket.assigns.selected_index
      end

    {:ok,
     socket
     |> assign(:folder, assigns.folder)
     |> assign(:all_folders, assigns.all_folders)
     |> assign(:current_tags, assigns.current_tags)
     |> assign(:recommended_nav_tags, recommended_nav_tags)
     |> assign(:indexed_tags, indexed_tags)
     |> assign(:is_admin, assigns.is_admin)
     |> assign(:max_recommended_tags, 20)
     |> assign(:selected_index, index)}
  end

  def handle_event("toggle_nav_panel", _, socket) do
    {:noreply, socket |> update(:is_open, fn is_open -> not is_open end)}
  end

  def handle_event("select_index", %{"index" => index}, socket) do
    # Get the tags for the selected index
    {:noreply, socket |> assign(:selected_index, index)}
  end

  # Util functions
  defp remove_diacritics(string) do
    string
    # Decompose into base characters and diacritics
    |> String.normalize(:nfkd)
    # Remove diacritical marks (Unicode "Mark, Nonspacing")
    |> String.replace(~r/\p{Mn}/u, "")
  end
end

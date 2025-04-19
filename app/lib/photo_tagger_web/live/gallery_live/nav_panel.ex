defmodule PhotoTaggerWeb.GalleryLive.NavPanel do
  use PhotoTaggerWeb, :live_component

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
          <%= if not Enum.empty?(@recommended_nav_tags) do %>
            <ul class="my-2">
              <%= for tag <- @recommended_nav_tags do %>
                <li class="mr-2 content-visible-auto">
                  <.toggle_button
                    selected={tag in @current_tags}
                    phx-click="toggle_tag"
                    phx-value-tag={tag}
                  >
                    {tag}
                  </.toggle_button>

                  <%!-- <.live_component
                    module={PhotoTaggerWeb.GalleryLive.GalleryTagLink}
                    id={tag}
                    tag={tag}
                    folder={@folder}
                    current_tags={@current_tags}
                    selected_photo_ids={@selected_photo_ids}
                    is_admin={@is_admin}
                    is_recommended={true}
                    is_selected={tag in @current_tags}
                  /> --%>
                </li>
              <% end %>
            </ul>
          <% end %>
          <%= if not Enum.empty?(@other_nav_tags) do %>
            <ul class="py-2">
              <%= for tag <- @other_nav_tags do %>
                <li class="mr-2 content-visible-auto">
                  <button class="underline text-blue-600 hover:text-blue-800 mr-2" phx-click="link_tag" phx-value-tag={tag} >
                    {tag}
                  </button>
                  <%!-- <.live_component
                    module={PhotoTaggerWeb.GalleryLive.GalleryTagLink}
                    id={tag}
                    tag={tag}
                    folder={@folder}
                    current_tags={@current_tags}
                    selected_photo_ids={@selected_photo_ids}
                    is_admin={@is_admin}
                    is_recommended={false}
                    is_selected={false}
                  /> --%>
                </li>
              <% end %>
            </ul>
          <% end %>
        </nav>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket |> assign(:is_open, true)}
  end

  def update(assigns, socket) do
    {recommended_nav_tags, other_nav_tags} =
      Enum.split_with(assigns.nav_tags, &(&1 in assigns.recommended_tags))

    recommended_nav_tags =
      Enum.sort_by(recommended_nav_tags, fn tag ->
        cond do
          # show currently selected tags first
          tag in assigns.current_tags -> 0
          # tag in @recommended_tag_names -> 1 # then recommended tags
          # then other tags
          true -> 2
        end
      end)

    {:ok,
     socket
     |> assign(:folder, assigns.folder)
     |> assign(:all_folders, assigns.all_folders)
     |> assign(:current_tags, assigns.current_tags)
     |> assign(:recommended_nav_tags, recommended_nav_tags)
     |> assign(:other_nav_tags, other_nav_tags)
     |> assign(:is_admin, assigns.is_admin)}
  end

  def handle_event("toggle_nav_panel", _, socket) do
    {:noreply, socket |> update(:is_open, fn is_open -> not is_open end)}
  end
end

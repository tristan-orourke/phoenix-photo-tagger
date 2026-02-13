defmodule PhotoTaggerWeb.GalleryLive.Main do
  use PhotoTaggerWeb, :live_view

  alias Phoenix.Component
  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo
  alias PhotoTagger.Uploaders.ImageUploader
  # alias PhotoTaggerWeb.HtmlHelpers
  alias PhotoTaggerWeb.GalleryLive.Util
  # import PhotoTaggerWeb.Components.Accordion

  require Logger

  @default_pg_size 100

  def render(assigns) do
    ~H"""
    <div class="h-full">
      <div class="flex flex-row gap-4 h-full">
        <div id="tags-section" class="shrink basis-2/7 lg:basis-1/7 overflow-y-auto">
          <.live_component
              id="nav-panel"
              module={PhotoTaggerWeb.GalleryLive.NavPanel}
              folder={@folder}
              all_folders={@all_folders}
              nav_tags={@nav_tags}
              recommended_tags={@recommended_tags}
              current_tags={@tags}
              exclude_tags={@exclude_tags}
              is_admin={@is_admin}
            />
              <%!-- all_folders={@all_folders} --%>
              <%!-- selected_photo_ids={@selected_photo_ids} --%>
              <%!-- folder={@folder} --%>
        </div>
        <div id="gallery-section" class="flex-grow basis-3/7 lg:basis-4/7 overflow-y-auto">
          <.gallery_header
            folder={@folder}
            tags={@tags}
            item_count={Enum.count(@filtered_photos)}
            multiselect_active={@multiselect_active}
            collapse_groups={@collapse_groups}
            is_admin={@is_admin}
            sort={@sort}
            show_visibility_outlines={@show_visibility_outlines}
          />
          <%!-- <.live_component
            id="gallery-panel"
            module={PhotoTaggerWeb.GalleryLive.GalleryPanel}
            photos={@filtered_photos}
            selected_photo_ids={@selected_photo_ids}
            collapse_groups={@collapse_groups}
            zoom_level={@zoom_level}
            is_admin={@is_admin}
          /> --%>
          <.gallery
            photos={@filtered_photos}
            selected_photo_ids={@selected_photo_ids}
            collapse_groups={@collapse_groups}
            collapse_group_exceptions={@collapse_group_exceptions}
            zoom_level={@zoom_level}
            is_admin={@is_admin}
            pg={@pg}
            pg_size={@pg_size}
            show_visibility_outlines={@show_visibility_outlines}
          />
        </div>
        <div id="photo-section" class="flex-none basis-2/7 overflow-y-auto [scrollbar-gutter:stable]">
          <%= case @selected_photos do %>
            <% [photo] -> %>
              <.photo
                photo={photo}
                folder={@folder}
                all_folders={@all_folders} tags={@tags} exclude_tags={@exclude_tags}
                all_tags={@all_tags} recommended_tags={@recommended_tags}
                related_tags={@recommended_tags}
                update_photo_form={@update_photo_form}
                is_admin={@is_admin} />
            <% [] -> %>
              <p class="text-center">Select a photo to view details</p>
            <% _ -> %>
              <%= if @is_admin do %>
                <.multi_photo_selection
                  photos={@selected_photos}
                  folder={@folder}
                  tags={@tags}
                  all_tags={@all_tags}
                  recommended_tags={@recommended_tags}
                  is_admin={@is_admin}
                />
              <% else %>
                <p class="text-center">Please select a single photo</p>
              <% end %>
          <% end %>
        </div>
      </div>
      <.modal id="expanded_photo">
        <div class="w-full min-h-screen lg:h-screen flex items-center justify-center">
        <%= case @selected_photos do %>
          <% [photo] -> %>
            <div
              class="lg:h-full p-2 flex items-center justify-center"
              phx-click-away={JS.exec("data-cancel", to: "#expanded_photo")}
            >
              <img
                class="object-contain max-w-full lg:max-h-full"
                alt={photo.name}
                src={ImageUploader.url({photo.image, photo}, :web_lg)}
              />
              <div class="absolute top-4 left-4 text-sm">
                <ul>
                  <li :for={tag <- photo.tags} class="shadow-zinc-700/10 ring-zinc-800 shadow-2xl bg-white ring-1 rounded-full px-1 my-1 w-fit text-sm">
                    #{tag.name}
                  </li>
                </ul>
                <div :if={@is_admin} class="mt-4">
                  <.form for={Component.to_form(%{"tag" => "", "photo_id" => photo.id})} phx-submit="add_tag">
                    <input class="hidden" type="text" name="photo_id" value={photo.id} />
                      <%!-- TODO: convert this simple inline form to a component --%>
                      <%!-- <.label for="add_any_tag_modal">Add tag</.label> --%>
                    <input
                      type="text"
                      name="tag"
                      id="add_any_tag_modal"
                      Placeholder="Add tag"
                      list="tag-list"
                      class="rounded-lg w-full max-w-40 text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 block mb-2 text-sm md:text-base"
                    />
                    <.button type="submit" class="text-sm md:text-base">Submit</.button>
                      <%!-- <datalist id="tag-list">
                        <%= for tag <- @all_tags do %>
                          <option value={tag} />
                        <% end %>
                      </datalist> --%>
                  </.form>
                </div>
              </div>
            </div>
          <% [] -> %>
            <p class="text-center">Select a photo to view details</p>
          <% _ -> %>
            <p class="text-center">Please select a single photo</p>
        <% end %>
        </div>
      </.modal>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    is_admin =
      case socket.assigns.live_action do
        :public -> false
        _ -> true
      end

    all_tags = Gallery.list_tags() |> Enum.map(& &1.name)

    {
      :ok,
      socket
      |> assign(:all_folders, Gallery.list_folders(include_private: is_admin))
      |> assign(:all_tags, all_tags)
      |> assign(:nav_tags, all_tags)
      |> assign(:multiselect_active, false)
      |> assign(:collapse_groups, true)
      |> assign(:collapse_group_exceptions, %{})
      |> assign(:zoom_level, 0)
      |> assign(:is_admin, is_admin)
      |> assign(:expand_photo, false)
      |> assign(:show_visibility_outlines, false)
      |> assign(:sort, :manual)
      |> assign(:last_selected_photo_id, nil),
      #  |> assign(%{
      #    folder: nil,
      #    tags: [],
      #    filtered_photos: [],
      #    selected_photos: [],
      #    recommended_tags: [],
      #    update_photo_form: Gallery.update_photo_changeset(%Photo{}) |> Component.to_form()
      #  })
      layout: {PhotoTaggerWeb.Layouts, if(is_admin, do: :admin, else: :app)}
    }
  end

  def handle_params(params, _session, socket) do
    folder = Map.get(params, "folder")
    tags = Map.get(params, "query_tags", [])
    exclude_tags = Map.get(params, "exclude_tags", [])
    photo_id = Map.get(params, "photo_id")
    selected_photo_ids = Map.get(params, "selected_photos", [])

    sort =
      case Map.get(params, "sort", "manual") do
        "date" -> :date
        "manual" -> :manual
        _ -> :manual
      end

    prev_pg = Map.get(socket.assigns, :pg, 1)

    pg =
      (Map.get(params, "pg") || Map.get(params, "page") || Integer.to_string(prev_pg))
      |> Util.safe_integer_parse(prev_pg)

    prev_pg_size = Map.get(socket.assigns, :pg_size, @default_pg_size)

    pg_size =
      Map.get(params, "pg_size", Integer.to_string(prev_pg_size))
      |> Util.safe_integer_parse(prev_pg_size)

    socket = assign(socket, %{pg: pg, pg_size: pg_size, sort: sort})

    # Set last_selected_photo_id when navigating to a photo URL, so shift-click range selection works
    socket =
      if photo_id != nil do
        assign(socket, :last_selected_photo_id, photo_id)
      else
        socket
      end

    # zoom_level =
    #   Map.get(params, "zoom", "0")
    #   |> Integer.parse()
    #   |> case do
    #     {zoom_level, _} -> zoom_level
    #     :error -> 0
    #   end

    expanded_state =
      expand_state(socket, %{
        folder: folder,
        tags: tags,
        exclude_tags: exclude_tags,
        photo_id: photo_id,
        selected_photo_ids: selected_photo_ids
      })

    # Reset scroll position of a section if the relevent params change
    socket =
      if(expanded_state.selected_photos != Map.get(socket.assigns, :selected_photos),
        do: push_event(socket, "scroll_to_top", %{selector: "#photo-section"}),
        else: socket
      )

    socket =
      if(expanded_state.folder != Map.get(socket.assigns, :folder),
        do: push_event(socket, "scroll_to_top", %{selector: "#tags-section"}),
        else: socket
      )

    socket =
      if(
        expanded_state.folder != Map.get(socket.assigns, :folder) or
          Enum.sort(expanded_state.tags) != Enum.sort(Map.get(socket.assigns, :tags, [])),
        do: push_event(socket, "scroll_to_top", %{selector: "#gallery-section"}),
        else: socket
      )

    {:noreply, assign(socket, expanded_state)}
  end

  def expand_state(
        socket,
        %{
          folder: folder,
          tags: tags,
          exclude_tags: exclude_tags,
          # This id comes from the url path
          photo_id: photo_id,
          # These come from url query params
          selected_photo_ids: selected_photo_ids
        }
      ) do
    prev_folder = Map.get(socket.assigns, :folder)
    prev_tags = Map.get(socket.assigns, :tags, [])
    prev_exclude_tags = Map.get(socket.assigns, :exclude_tags, [])
    prev_filtered_photos = Map.get(socket.assigns, :filtered_photos, nil)
    _action = Map.get(socket.assigns, :live_action, nil)
    is_admin = Map.get(socket.assigns, :is_admin, false)
    sort = Map.get(socket.assigns, :sort, :manual)
    prev_sort = Map.get(socket.assigns, :prev_sort, sort)

    filtered_photos =
      case {folder, tags, exclude_tags, prev_filtered_photos} do
        # If the folder, tags, and sort are unchanged, and we have previously cached filtered photos, use them without querying the database
        {^prev_folder, ^prev_tags, ^prev_exclude_tags, prev_filtered_photos}
        when is_list(prev_filtered_photos) and prev_filtered_photos != [] and sort == prev_sort ->
          prev_filtered_photos

        {nil, [], [], _} ->
          Gallery.list_photos(include_private: is_admin, sort: sort, exclude_cross_listings: false)

        {nil, ["untagged"], _, _} ->
          Gallery.list_photos_by_all_tags(nil, include_private: is_admin, sort: sort, exclude_cross_listings: false) ++
            Gallery.list_photos_by_tags(%{include: ["untagged"], exclude: []},
              include_private: is_admin,
              sort: sort,
              exclude_cross_listings: false
            )

        {nil, tags, exclude_tags, _} ->
          Gallery.list_photos_by_tags(%{include: tags, exclude: exclude_tags},
            include_private: is_admin,
            sort: sort,
            exclude_cross_listings: false
          )

        {folder, [], [], _} ->
          Gallery.list_photos_by_folder(folder, include_private: is_admin, sort: sort)

        {folder, ["untagged"], _, _} ->
          # TODO:
          Gallery.list_photos_by_folder_and_tags(folder, %{include: nil, exclude: []},
            include_private: is_admin,
            sort: sort
          ) ++
            Gallery.list_photos_by_folder_and_tags(folder, %{include: ["untagged"], exclude: []},
              include_private: is_admin,
              sort: sort
            )

        {folder, tags, exclude_tags, _} ->
          Gallery.list_photos_by_folder_and_tags(folder, %{include: tags, exclude: exclude_tags},
            include_private: is_admin,
            sort: sort
          )
      end

    prev_selected_photos = Map.get(socket.assigns, :selected_photos, nil)

    prev_selected_photo_ids =
      case prev_selected_photos do
        nil -> nil
        _ -> Enum.map(prev_selected_photos, & &1.id)
      end

    new_selected_photo_ids =
      [photo_id | selected_photo_ids]
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(&String.to_integer/1)

    selected_photos =
      case {new_selected_photo_ids, prev_selected_photos} do
        # If the selected photo ids have not changed, and we have cached selected photos, use them without querying the database
        {^prev_selected_photo_ids, prev_selected_photos} when is_list(prev_selected_photos) ->
          prev_selected_photos

        # Otherwise, selections have changed, query them from the database
        {_, _} ->
          new_selected_photo_ids
          |> Gallery.get_photos_by_ids(include_private: is_admin)
          |> Repo.preload([:tags, :folder, cross_listings: :folder, original_photo: :folder])
      end

    nav_tags =
      case folder do
        ^prev_folder -> Map.get(socket.assigns, :nav_tags, [])
        nil -> socket.assigns.all_tags
        _ -> Gallery.list_tags_by_folder(folder) |> Enum.map(& &1.name)
      end

    # recommended tags are the tags which can be added to the current selection of tags
    #   without resulting in an empty gallery
    recommended_tags =
      case tags do
        [] ->
          nav_tags

        ^prev_tags ->
          Map.get(socket.assigns, :recommended_tags, [])

        _ ->
          # filtered_photos
          # |> Repo.preload(:tags)
          # |> Enum.flat_map(& &1.tags)
          Gallery.list_tags_by_photos(filtered_photos |> Enum.map(& &1.id))
          |> Enum.map(& &1.name)
      end

    update_photo_form =
      case selected_photos do
        [photo] -> photo
        # If no photos are selected, or many are, start form changeset from a blank photo struct
        _ -> %Photo{}
      end
      |> Gallery.update_photo_changeset()
      |> Component.to_form()

    %{
      folder: folder,
      tags: tags,
      exclude_tags: exclude_tags,
      # Take only the fields we need to display in the gallery. This reduces the frequency of changes to the gallery.
      filtered_photos:
        filtered_photos
        |> Enum.map(&simplify_photo/1),
      selected_photos: selected_photos,
      selected_photo_ids: new_selected_photo_ids,
      recommended_tags: recommended_tags,
      nav_tags: nav_tags,
      update_photo_form: update_photo_form,
      prev_sort: sort
    }
  end

  attr(:folder, :string, default: nil)
  attr(:selected_photo_ids, :list, default: [])
  attr(:tags, :list, default: [])
  attr(:exclude_tags, :list, default: [])
  attr(:toggled_tag, :string, required: true)
  attr(:is_admin, :boolean, required: true)
  slot(:inner_block)

  def toggle_tag_button(assigns) do
    tags_list =
      cond do
        assigns.toggled_tag == nil ->
          assigns.tags

        assigns.toggled_tag in assigns.tags ->
          Enum.filter(assigns.tags, &(&1 != assigns.toggled_tag))

        true ->
          assigns.tags ++ [assigns.toggled_tag]
      end

    new_exclude_tags = Enum.filter(assigns.exclude_tags, &(&1 != assigns.toggled_tag))

    assigns =
      assign(
        assigns,
        :href,
        Util.build_url(
          assigns.folder,
          assigns.selected_photo_ids,
          tags_list,
          new_exclude_tags,
          assigns.is_admin
        )
      )

    assigns = assign(assigns, :selected, assigns.toggled_tag in assigns.tags)

    ~H"""
    <.toggle_link
      selected={@selected}
      href={@href}
    >
      {render_slot(@inner_block)}
    </.toggle_link>
    """
  end

  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])
  attr(:item_count, :integer, required: true)
  attr(:multiselect_active, :boolean, required: true)
  attr(:collapse_groups, :boolean, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:sort, :atom, default: :manual)
  attr(:show_visibility_outlines, :boolean, default: false)

  def gallery_header(assigns) do
    breadcrumb_tags = Enum.scan(assigns.tags, [], fn tag, acc -> [tag | acc] end)
    assigns = assign(assigns, :breadcrumb_tags, breadcrumb_tags)

    ~H"""
    <div class="md:flex sticky top-0 bg-white z-50">
      <nav aria-label="Breadcrumb" class="flex-grow pb-1">
        <ul class="flex flex-wrap items-center">
          <li class="align-middle pr-2">
            <.icon name="hero-folder" class=" w-4 h-4 lg:w-5 lg:h-5"/>
            <.link
              id="breadcrumb-folder"
              aria-current={if(length(@breadcrumb_tags) == 0, do: "page", else: "false")}
              patch={Util.build_url(@folder, [], [], [], @is_admin)}
            >
              {@folder || "All folders"}
            </.link>
          </li>
          <%= for {[tag | _] = tags, index} <- Enum.with_index(@breadcrumb_tags) do %>
            <li id="breadcrumb-tags" class="">
              <.icon name="hero-chevron-right" class="hero-chevron-right-mini lg:hero-chevron-right w-4 h-4 lg:w-5 lg:h-5"/>
              <.link
                aria-current={if(index == length(@breadcrumb_tags) - 1, do: "page", else: "false")}
                patch={Util.build_url(@folder, [], Enum.reverse(tags), [], @is_admin)}
              >
                #{tag}
              </.link>
            </li>
          <% end %>
        </ul>
      </nav>
      <div class="flex-none pb-1 lg:pb-2 flex flex-row-reverse flex-wrap items-center">
        <div class="flex-none pr-3">
          <.button class="p-1 flex items-center" phx-click="zoom_out">
            <.icon name="hero-magnifying-glass-minus" class="hero-magnifying-glass-minus-mini lg:hero-magnifying-glass-minus w-4 h-4 lg:w-5 lg:h-5" />
          </.button>
        </div>
        <div class="flex-none pr-1">
          <.button class="p-1 flex items-center" phx-click="zoom_in">
            <.icon name="hero-magnifying-glass-plus" class="hero-magnifying-glass-plus-mini lg:hero-magnifying-glass-plus w-4 h-4 lg:w-5 lg:h-5" />
          </.button>
        </div>
        <div class="flex-none mr-3 lg:ml-3">
          <p class="font-bold">{"#{@item_count}"}<span class="hidden md:inline">{" items"}</span></p>
        </div>
        <div class="flex-none pr-3">
          <form phx-change="change_sort" class="flex items-center">
            <label class="sr-only lg:not-sr-only text-sm mr-2">Sort:</label>
            <select id="sort-select" name="sort" class="text-sm rounded-lg border-gray-300 ml-1 py-1 pl-2 pr-8">
              <option value="date" selected={@sort == :date}>Date</option>
              <option value="manual" selected={@sort == :manual}>Curated</option>
            </select>
          </form>
        </div>
        <div class="flex-none pr-3">
          <.toggle_button
            id="collapse-groups-toggle"
            selected={!@collapse_groups}
            phx-click="toggle_collapse_groups"
            class="flex items-center pl-3 pr-3 inline mr-1"
          >
            <.icon name="hero-square-3-stack-3d" class="hero-square-3-stack-3d-mini lg:hero-square-3-stack-3d my-1 lg:my-0 w-4 h-4 lg:w-5 lg:h-5" />
            <span class="sr-only lg:not-sr-only lg:ml-1">
              {if(@collapse_groups, do: "Expand groups", else: "Collapse groups")}
            </span>
          </.toggle_button>
          <.toggle_button
            :if={@is_admin}
            id="multiselect-toggle"
            selected={@multiselect_active}
            phx-click="toggle_multiselect"
            class="flex items-center pl-3 pr-3 inline"
          >
            <.icon name="hero-squares-plus" class="hero-squares-plus-mini lg:hero-squares-plus my-1 lg:my-0 w-4 h-4 lg:w-5 lg:h-5" />
            <span class="sr-only lg:not-sr-only lg:ml-1">
              Multiselect
            </span>
          </.toggle_button>
          <.toggle_button
            :if={@is_admin}
            selected={@show_visibility_outlines}
            phx-click="toggle_visibility_outlines"
            class="flex items-center pl-3 pr-3 inline ml-1"
          >
            <.icon name="hero-eye" class="hero-eye-mini lg:hero-eye my-1 lg:my-0 w-4 h-4 lg:w-5 lg:h-5" />
            <span class="sr-only lg:not-sr-only lg:ml-1">
              Visibility
            </span>
          </.toggle_button>
        </div>
      </div>
    </div>
    """
  end

  attr(:pg, :integer, default: 1)
  attr(:pg_size, :integer, default: @default_pg_size)
  attr(:total_items, :integer, required: true)

  def pagination(assigns) do
    assigns =
      assign(assigns, :total_pages, Util.ceiling_div(assigns.total_items, assigns.pg_size))

    ~H"""
    <div :if={@total_pages > 1} class="flex flex-col md:flex-row justify-center mb-2 mb:mb-4">
      <.button
        phx-click="change_page"
        phx-value-pg={1}
        class={"m-1 py-1 lg:py-2 #{if @pg > 2, do: "", else: "hidden md:inline md:invisible"}"}
      >
        First
      </.button>
      <.button
        phx-click="change_page"
        phx-value-pg={@pg - 1}
        class={"m-1 py-1 lg:py-2 #{if(@pg > 1, do: "", else: "hidden md:inline md:invisible")}"}
      >
        Previous
      </.button>
      <span class="self-center">
        <span class="hidden lg:inline">Page </span>
        <input id="page-input" type="hidden" value={@pg} />
        {@pg} of {@total_pages}
      </span>
      <.button
        phx-click="change_page"
        phx-value-pg={@pg + 1}
        class={"m-1 py-1 lg:py-2 #{if(@pg < @total_pages, do: "", else: "hidden md:inline md:hidden md:inline md:invisible")}"}
      >
        Next
      </.button>
      <.button
        phx-click="change_page"
        phx-value-pg={@total_pages}
        class={"m-1 py-1 lg:py-2 #{if @pg < (@total_pages - 1), do: "", else: "hidden md:inline md:invisible"}"}
      >
        Last
      </.button>
    </div>
    """
  end

  attr(:photos, :list, required: true)
  attr(:selected_photo_ids, :list, default: [])
  attr(:collapse_groups, :boolean, default: false)
  attr(:collapse_group_exceptions, :map, default: %{})
  attr(:zoom_level, :integer, default: 0)
  attr(:is_admin, :boolean, required: true)
  attr(:pg, :integer, default: 1)
  attr(:pg_size, :integer, default: @default_pg_size)
  attr(:show_visibility_outlines, :boolean, default: false)

  def gallery(assigns) do
    groups = Enum.map(assigns.photos, & &1.group) |> Enum.uniq() |> Enum.reject(&is_nil/1)

    # Filter out photos in collapse groups, excepting the first in any group
    grouped_photos = Enum.group_by(assigns.photos, & &1.group)

    filtered_photos =
      Enum.filter(assigns.photos, fn photo ->
        photo.group == nil or
          !Map.get(assigns.collapse_group_exceptions, photo.group, assigns.collapse_groups) or
          photo == List.first(grouped_photos[photo.group])
      end)

    group_header_positions =
      Enum.map(
        groups,
        fn group ->
          {group, Enum.find_index(filtered_photos, &(&1.group == group))}
        end
      )
      |> Enum.into(%{})

    # Ensure photos in a group appear next to each other, without otherwise changing the order.
    # For each group, the first photo in the group is kept in its original position, with the rest of the group directly following, retaining their relaitve ordering.
    sorted_photos =
      filtered_photos
      |> Enum.with_index()
      |> Enum.sort_by(fn {photo, index} ->
        case photo.group do
          nil -> {index, 0}
          group -> {group_header_positions[group] || index, index}
        end
      end)
      |> Enum.map(fn {photo, _index} -> photo end)

    paginated_photos =
      Enum.slice(sorted_photos, (assigns.pg - 1) * assigns.pg_size, assigns.pg_size)

    assigns =
      assign(
        assigns,
        :photos,
        paginated_photos
      )
      |> assign(:total_items, Enum.count(sorted_photos))

    ~H"""
    <div class="p-2 lg:p-6">
      <.pagination total_items={@total_items} pg={@pg} pg_size={@pg_size} />
      <ul
        id="gallery-grid"
        data-zoom-level={@zoom_level}
        class={"grid
      #{get_grid_size(@zoom_level, 1)}
      md:#{get_grid_size(@zoom_level, 2)}
      lg:#{get_grid_size(@zoom_level, 4)}
      xl:#{get_grid_size(@zoom_level, 4)}
      2xl:#{get_grid_size(@zoom_level, 6)}"}>
        <%= for {photo, index} <- Enum.with_index(@photos) do %>
          <.live_component
            module={PhotoTaggerWeb.GalleryLive.GalleryPhoto}
            id={photo.id}
            photo_id={photo.id}
            photo_group={photo.group}
            photo_name={photo.name}
            photo_image={photo.image}
            photo_folder={Gallery.storage_folder(photo)}
            is_selected={photo.id in @selected_photo_ids}
            is_group_collapsed={Map.get(@collapse_group_exceptions, photo.group, @collapse_groups)}
            is_group_topper={
              photo.group != nil and
                (index == 0 or photo.group != Enum.at(@photos, index - 1).group)
            }
            is_admin={@is_admin}
            group_left={photo.group != nil and index > 0 and photo.group == Enum.at(@photos, index - 1).group}
            group_right={
              photo.group != nil and index < length(@photos) - 1 and photo.group == Enum.at(@photos, index + 1).group
            }
            photo_is_public={photo.is_public}
            show_visibility_outline={@show_visibility_outlines}
          />
        <% end %>
      </ul>
      <.pagination total_items={@total_items} pg={@pg} pg_size={@pg_size} />
    </div>
    """
  end

  defp get_grid_size(zoom_level, base_size) do
    size = clamp(base_size - zoom_level, 1, 9)
    "grid-cols-#{size}"
  end

  attr(:photo, :map, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])
  attr(:exclude_tags, :list, default: [])
  attr(:recommended_tags, :list, default: [])
  attr(:all_tags, :list, required: true)
  attr(:related_tags, :list, required: true)
  attr(:update_photo_form, :map, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:all_folders, :list, required: true)

  def photo(assigns) do
    assigns = assign(assigns, :folder_is_active, assigns.folder == assigns.photo.folder.name)
    assigns = assign(assigns, :cross_listings_with_folders,
      Repo.preload(assigns.photo.cross_listings, :folder))

    ~H"""
    <.list>
      <%!-- On medium screens and above, sticky the image section to the top --%>
      <:item title="Image" class="w-full lg:sticky lg:top-0 lg:bg-white lg:border-b lg:border-zinc-100 lg:mb-4 lg:z-10">
        <button
          class="relative w-full max-h-[40vh] square-image group"
          phx-click={show_modal("expanded_photo")}
        >
          <img
            class="object-contain w-full h-full aspect-square"
            alt={@photo.name}
            src={ImageUploader.url({@photo.image, @photo}, :web_md)}
          />
          <div class="absolute top-0 right-2 lg:p-3 flex-none opacity-30 lg:opacity-20 group-hover:opacity-40 text-zinc-500">
            <.icon name="hero-arrows-pointing-out" class="h-6 w-6 group-hover:h-7 group-hover:w-7" />
          </div>
        </button>
      </:item>
      <:item title="Folder" :if={@is_admin}>
        <div class="flex items-center gap-2">
          <.link
            class="data-[active]:font-bold"
            patch={Util.build_url(@photo.folder.name, [@photo.id], @tags, @exclude_tags, @is_admin)}
            data-active={@folder_is_active}
          >
            {@photo.folder.name}
          </.link>
          <p :if={@is_admin} class={"text-sm px-2 py-0.5 rounded-full border #{if @photo.is_public, do: "text-green-600 border-green-600", else: "text-red-600 border-red-600"}"}>
            {if @photo.is_public, do: "public", else: "private"}
          </p>
          <p :if={@is_admin and Gallery.is_cross_listing?(@photo)}
             class="text-sm px-2 py-0.5 rounded-full border text-purple-600 border-purple-600">
            cross-listed from
            <.link patch={Util.build_url(@photo.original_photo.folder.name, [@photo.original_photo.id], @tags, @exclude_tags, @is_admin)}
                   class="underline hover:text-purple-800">
              {@photo.original_photo.folder.name}
            </.link>
          </p>
        </div>
      </:item>
      <:item title="Cross-listed in" :if={@is_admin and not Gallery.is_cross_listing?(@photo) and not Enum.empty?(@photo.cross_listings)}>
        <div class="text-sm text-zinc-600">
          <span class="font-medium">Cross-listed in: </span>
          <%= for {listing, index} <- Enum.with_index(@cross_listings_with_folders) do %>
            <.link patch={Util.build_url(listing.folder.name, [listing.id], @tags, @exclude_tags, @is_admin)}
                   class="text-purple-600 hover:text-purple-800 underline">
              {listing.folder.name}
            </.link><%= if index < length(@cross_listings_with_folders) - 1, do: ", " %>
          <% end %>
        </div>
      </:item>
      <:item title="Tags" :if={@is_admin or not Enum.empty?(@photo.tags)}>
        <ul class="flex flex-wrap">
          <%= for tag <- @photo.tags do %>
          <%!-- Note that @photo.tags are full structs, including id, not just a name like our other tag lists --%>
            <li class="mr-2 flex items-center">
              <%= if tag.name in @recommended_tags do %>
                <.toggle_tag_button
                  folder={@folder}
                  selected_photo_ids={[@photo.id]}
                  tags={@tags}
                  exclude_tags={@exclude_tags}
                  toggled_tag={tag.name}
                  is_admin={@is_admin}
                >
                  #{tag.name}
                </.toggle_tag_button>
              <% else %>
                <.link patch={Util.build_url(@folder, [@photo.id], [tag.name], @exclude_tags, @is_admin)}>
                  #{tag.name}
                </.link>
              <% end %>
              <.form
                :if={@is_admin}
                for={Component.to_form(%{"tag" => tag.name, "photo_id" => @photo.id})}
                phx-submit="remove_tag"
              >
                <input class="hidden" type="text" name="photo_id" value={@photo.id} />
                <input class="hidden" type="text" name="tag" value={tag.name} />
                <button type="submit" class="flex items-center">
                  <.icon name="hero-trash-micro" class="text-red-700 hover:text-red-900" />
                </button>
              </.form>
            </li>
          <% end %>
        </ul>
        <div :if={@is_admin} class="mt-2">
          <.form for={Component.to_form(%{"tag" => "", "photo_id" => @photo.id})} phx-submit="add_tag">
            <input class="hidden" type="text" name="photo_id" value={@photo.id} />
            <div class="flex flex-wrap gap-2">
              <%!-- TODO: convert this simple inline form to a component --%>
              <%!-- <.label for="add_any_tag">Add tag</.label> --%>
              <input
                type="text"
                name="tag"
                id="add_any_tag"
                Placeholder="Add tag"
                list="tag-list"
                class="rounded-lg w-full max-w-40 text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
              />
              <.button type="submit">Submit</.button>
              <%!-- <datalist id="tag-list">
                <%= for tag <- @all_tags do %>
                  <option value={tag} />
                <% end %>
              </datalist> --%>
            </div>
          </.form>
        </div>
        <%!-- TODO: restore some version of recommended tags --%>
        <%!-- <%= if @is_admin do %>
          <.accordion id="photo-add-related-tags" class="mt-2">
            <:trigger>
              <p class="text-left">Quick add</p>
            </:trigger>
            <:panel>
              <div class="flex flex-wrap mt-2">
                <%= for tag <- @related_tags do %>
                  <div class="mr-2">
                    <.form
                      for={Component.to_form(%{"tag" => tag, "photo_id" => @photo.id})}
                      phx-submit="add_tag"
                    >
                      <input class="hidden" type="text" name="photo_id" value={@photo.id} />
                      <input class="hidden" type="text" name="tag" value={tag} />
                      <button
                        class="border border-blue-600 rounded-full hover:bg-blue-100 px-1 my-1 text-blue-600 hover:text-blue-800"
                        type="submit"
                      >
                        {tag}
                      </button>
                    </.form>
                  </div>
                <% end %>
              </div>
            </:panel>
          </.accordion>
        <% end %> --%>
      </:item>
      <%!-- <:item title="Related tags">
        <ul class="flex flex-wrap">
          <%= for tag <- @related_tags do %>
            <li class="mr-2 flex items-center">
              <%= if tag in @recommended_tags do %>
                <.toggle_tag_button
                  folder={@folder}
                  selected_photos={[@photo]}
                  tags={@tags}
                  toggled_tag={tag}
                  is_admin={@is_admin}
                >
                  <span class="hidden md:inline">{if(tag in @tags, do: "- ", else: "+ ")}</span>{tag}
                </.toggle_tag_button>
              <% else %>
                <.link patch={Util.build_url(@folder, [@photo.id], [tag], @is_admin)}>
                  {tag}
                </.link>
              <% end %>
            </li>
          <% end %>
        </ul>
      </:item> --%>
      <:item title="Download file">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)} download>
          {@photo.name}
        </.link>
      </:item>
      <:item title="Details" :if={not @is_admin and (@photo.notes || @photo.description || @photo.image_last_modified)}>
        <p :if={@photo.notes}>Notes: {@photo.notes}</p>
        <p :if={@photo.description}>Description: {@photo.description}</p>
        <p :if={@photo.image_last_modified}>Last modified: {@photo.image_last_modified}</p>
      </:item>
      <:item title="Edit" :if={@is_admin}>
        <.form for={@update_photo_form} id="update-photo-form" phx-submit="update_photo">
          <input class="hidden" type="text" name="photo_id" value={@update_photo_form.data.id} />
          <.input field={@update_photo_form[:name]} name="photo[name]" type="text" label="Name" />
          <.input class="mt-1" field={@update_photo_form[:is_public]} name="photo[is_public]" type="checkbox"
            label="Is public" />
          <.input field={@update_photo_form[:folder_id]} name="photo[folder_id]" type="select"
            label="Folder" required options={Enum.map(@all_folders, &([key: &1.name, value: &1.id]))} />
          <.input
            field={@update_photo_form[:notes]}
            name="photo[notes]"
            type="textarea"
            label="Notes"
          />
          <.input
            field={@update_photo_form[:description]}
            name="photo[description]"
            type="textarea"
            label="Description"
          />
          <.input
            field={@update_photo_form[:group]}
            name="photo[group]"
            type="text"
            label="Group"
          />
          <.input
            field={@update_photo_form[:manual_order]}
            name="photo[manual_order]"
            type="number"
            label="Curated order"
          />
          <.button class="mt-4">Save</.button>
        </.form>
      </:item>
      <:item title="Cross-list to folder" :if={@is_admin and not Gallery.is_cross_listing?(@photo)}>
        <div :if={not Enum.empty?(@photo.cross_listings)} class="mb-3 text-sm text-zinc-600">
          <p class="font-medium">Already cross-listed in:</p>
          <ul class="list-disc ml-4 mt-1">
            <%= for listing <- @cross_listings_with_folders do %>
              <li>
                <.link patch={Util.build_url(listing.folder.name, [listing.id], [], [], @is_admin)}
                       class="text-blue-600 hover:underline">
                  {listing.folder.name}
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
        <.form for={Component.to_form(%{"photo_id" => @photo.id, "folder_id" => ""})}
               phx-submit="create_cross_listing">
          <input class="hidden" type="text" name="photo_id" value={@photo.id} />
          <div class="flex gap-2">
            <select name="folder_id" class="rounded-lg text-sm text-zinc-900">
              <option value="">Select folder...</option>
              <%= for folder <- available_cross_list_folders(@photo, @all_folders) do %>
                <option value={folder.id}>{folder.name}</option>
              <% end %>
            </select>
            <.button type="submit">Cross-list</.button>
          </div>
        </.form>
      </:item>
      <:item title="Image last modified" :if={@is_admin and @photo.image_last_modified}>
        <p>{@photo.image_last_modified}</p>
      </:item>
      <:item title="Remove" :if={@is_admin and Gallery.is_cross_listing?(@photo)}>
        <.form
          phx-submit="remove_cross_listing"
          for={Component.to_form(%{"photo_id" => @photo.id})}
          onsubmit="return confirm('Remove this cross-listing? The original photo will remain in its folder.')"
        >
          <input class="hidden" type="text" name="photo_id" value={@photo.id} />
          <.button class="bg-orange-600 hover:bg-orange-700">Remove cross-listing</.button>
        </.form>
      </:item>
      <:item title="Delete" :if={@is_admin and not Gallery.is_cross_listing?(@photo)}>
        <.form
          phx-submit="delete_photo"
          for={Component.to_form(%{"photo_id" => @photo.id})}
          onsubmit={"return confirm('#{delete_confirmation_message(@photo)}')"}
        >
          <input class="hidden" type="text" name="photo_id" value={@photo.id} />
          <.button class="bg-red-600 hover:bg-red-900">
            {delete_button_text(@photo)}
          </.button>
        </.form>
      </:item>
      <:item title="Drift">
        <.link
          class="text-blue-600 hover:text-blue-800"
          patch={Util.build_url(@folder, [@photo.id], @tags, @exclude_tags, false, "drift")}
        >
          drift<.icon name="hero-arrow-up-right" class="w-3 h-3 ml-1" />
        </.link>
      </:item>
    </.list>
    """
  end

  attr(:photos, :list, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])
  attr(:all_tags, :list, required: true)
  attr(:recommended_tags, :list, default: [])
  attr(:is_admin, :boolean, required: true)

  def multi_photo_selection(assigns) do
    {tags_to_add, tags_to_remove, tags_in_limbo} =
      Enum.reduce(assigns.all_tags, {[], [], []}, fn tag, {add, remove, limbo} ->
        case Enum.reduce(assigns.photos, {0, 0}, fn photo, {has_tag_count, missing_count} ->
               case Enum.any?(photo.tags, fn t -> t.name == tag end) do
                 true -> {has_tag_count + 1, missing_count}
                 false -> {has_tag_count, missing_count + 1}
               end
             end) do
          # All photos have this tag
          {_, 0} -> {tag, [tag | remove], limbo}
          # No photos have this tag
          {0, _} -> {[tag | add], remove, limbo}
          # Some photos have this tag
          _ -> {add, remove, [tag | limbo]}
        end
      end)

    assigns = assign(assigns, :tags_to_add, tags_to_add)
    assigns = assign(assigns, :tags_to_remove, tags_to_remove)
    assigns = assign(assigns, :tags_in_limbo, tags_in_limbo)

    assigns = assign(assigns, :groups, Enum.uniq(Enum.map(assigns.photos, & &1.group)))

    {public_count, private_count} =
      Enum.reduce(assigns.photos, {0, 0}, fn photo, {pub, priv} ->
        if photo.is_public, do: {pub + 1, priv}, else: {pub, priv + 1}
      end)

    assigns = assign(assigns, :public_count, public_count)
    assigns = assign(assigns, :private_count, private_count)

    ~H"""
    <.list>
      <:item title="Selected photos">
        <ul class="flex flex-wrap gap-2 p-2">
          <%= for photo <- @photos do %>
            <li class="w-20 h-20">
              <button class="h-full" phx-click="select_gallery_photo" phx-value-photo_id={photo.id}>
                <%!-- use object-cover for cropped squares, and object-contain for shrinked full images --%>
                <img
                  class="w-20 h-20 object-cover"
                  alt={photo.name}
                  src={ImageUploader.url({photo.image, photo}, :thumb)}
                />
              </button>
            </li>
          <% end %>
        </ul>
      </:item>
      <:item title="Remove tags">
        <ul class="flex flex-wrap">
          <%= for tag <- (@tags_to_remove ++ @tags_in_limbo) do %>
            <li class="mr-2">
              <.form
                class="inline"
                for={Component.to_form(%{"tag" => tag})}
                phx-submit="remove_tag_bulk"
              >
                <input class="hidden" type="text" name="tag" value={tag} />
                <button
                  class="border border-red-600 rounded-full hover:bg-red-100 px-1 my-1 text-red-600 hover:text-red-800"
                  type="submit"
                >
                  {tag}
                </button>
              </.form>
            </li>
          <% end %>
        </ul>
      </:item>
      <:item title="Add tags">
        <div class="mt-4">
          <.form for={Component.to_form(%{"tag" => ""})} phx-submit="add_tag_bulk">
            <div class="flex flex-wrap gap-2">
              <%!-- TODO: convert this simple inline form to a component --%>
              <%!-- <.label for="add_any_tag_multi">Add tag</.label> --%>
              <input
                type="text"
                name="tag"
                id="add_any_tag_multi"
                Placeholder="Add tag"
                class="w-full max-w-40 rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
              />
              <.button type="submit">Submit</.button>
            </div>
          </.form>
        </div>
        <div class="flex flex-wrap mt-2">
          <%= for tag <- @recommended_tags do %>
            <%= if (tag not in @tags_to_remove) do %>
              <div class="mr-2">
                <.form for={Component.to_form(%{"tag" => tag})} phx-submit="add_tag_bulk">
                  <input class="hidden" type="text" name="tag" value={tag} />
                  <button
                    class="border border-blue-600 rounded-full hover:bg-blue-100 px-1 my-1 text-blue-600 hover:text-blue-800"
                    type="submit"
                  >
                    {tag}
                  </button>
                </.form>
              </div>
            <% end %>
          <% end %>
        </div>
      </:item>
      <:item title="Group">
        <p :if={Enum.count(@groups) > 1}>Photos belong to multiple groups:</p>
        <ul class="list-disc list-inside mb-2">
          <%= for group <- @groups do %>
            <li>{if group != nil, do: group, else: "No group"}</li>
          <% end %>
        </ul>
        <.form for={Component.to_form(%{})} phx-submit="form_group_from_selected">
          <div class="flex flex-wrap gap-2">
            <.button type="submit">Form group</.button>
          </div>
        </.form>
        <.form :if={Enum.count(@groups) > 0} class="pt-2" for={Component.to_form(%{"group" => ""})} phx-submit="set_group_bulk">
          <input
            class="hidden"
            type="text"
            name="group"
            id="bulk_group_input"
            value=""
          />
          <.button type="submit">Ungroup</.button>
        </.form>
      </:item>
      <:item title="Visibility">
        <p class="mb-2">
          <%= cond do %>
            <% @private_count == 0 -> %>Visibility: All public
            <% @public_count == 0 -> %>Visibility: All private
            <% true -> %>Mixed visibility: {@public_count} public, {@private_count} private
          <% end %>
        </p>
        <div class="flex flex-wrap gap-2">
          <.form :if={@private_count > 0} for={Component.to_form(%{"is_public" => "true"})} phx-submit="set_visibility_bulk">
            <input type="hidden" name="is_public" value="true" />
            <.button type="submit">
              Make all public
            </.button>
          </.form>
          <.form :if={@public_count > 0} for={Component.to_form(%{"is_public" => "false"})} phx-submit="set_visibility_bulk">
            <input type="hidden" name="is_public" value="false" />
            <.button type="submit">
              Make all private
            </.button>
          </.form>
        </div>
      </:item>
      <:item title="Cross-list to folder">
        <.form for={Component.to_form(%{"folder_id" => ""})} phx-submit="create_cross_listing_bulk">
          <div class="flex gap-2">
            <select name="folder_id" class="rounded-lg text-sm text-zinc-900">
              <option value="">Select folder...</option>
              <%= for folder <- Gallery.list_folders(include_private: @is_admin) do %>
                <option value={folder.id}>{folder.name}</option>
              <% end %>
            </select>
            <.button type="submit">Cross-list selected</.button>
          </div>
        </.form>
      </:item>
      <:item title="Delete">
        <.form
          phx-submit="delete_photo_bulk"
          for={Component.to_form(%{})}
          onsubmit="return confirm('Are you sure you want to permanently delete these photos?')"
        >
          <.button class="bg-red-600 hover:bg-red-900">Delete</.button>
        </.form>
      </:item>
    </.list>
    """
  end

  def handle_multi_photo_select(photo_id, socket) do
    selected_photos = socket.assigns.selected_photos
    # Remove the new photo from selected_photos if it is present, otherwise add it
    new_selection =
      if(
        Enum.any?(selected_photos, &(to_string(&1.id) == photo_id)),
        do: Enum.filter(selected_photos, &(to_string(&1.id) != photo_id)),
        else: [%{id: photo_id} | selected_photos]
      )
      |> Enum.map(& &1.id)

    {:noreply,
     push_patch(socket,
       to:
         Util.build_url(
           socket.assigns.folder,
           new_selection,
           socket.assigns.tags,
           socket.assigns.exclude_tags,
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort,
           socket.assigns.pg
         )
     )
     |> assign(:last_selected_photo_id, photo_id)}
  end

  def handle_single_photo_select(photo_id, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Util.build_url(
           socket.assigns.folder,
           [photo_id],
           socket.assigns.tags,
           socket.assigns.exclude_tags,
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort,
           socket.assigns.pg
         )
     )
     |> assign(:last_selected_photo_id, photo_id)}
  end

  def handle_photo_group_select(photo_id, photo_group, ctrl_key_pressed, socket) do
    group_photos = Enum.filter(socket.assigns.filtered_photos, &(&1.group == photo_group))

    group_already_selected =
      Enum.all?(group_photos, &member_by_id?(socket.assigns.selected_photos, &1))

    # If not in multiselect mode, select all photos in the group
    # If in multiselect mode, and all photos in the group are already selected, remove them from the selection
    # If in multiselect mode, and some or no photos in the group are already selected, add all of them to the selection
    new_selected_photos =
      case {ctrl_key_pressed, socket.assigns.multiselect_active, group_already_selected} do
        {false, false, _} -> group_photos
        {_, _, true} -> Enum.filter(socket.assigns.selected_photos, &(&1.group != photo_group))
        {_, _, false} -> Enum.concat(socket.assigns.selected_photos, group_photos) |> Enum.uniq()
      end
      |> Enum.map(& &1.id)

    {:noreply,
     push_patch(socket,
       to:
         Util.build_url(
           socket.assigns.folder,
           new_selected_photos,
           socket.assigns.tags,
           socket.assigns.exclude_tags,
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort
         )
     )
     |> assign(:last_selected_photo_id, photo_id)}
  end

  def handle_shift_range_select(photo_id, socket) do
    last_selected_id = socket.assigns.last_selected_photo_id

    # If there's no last selected photo, treat as normal multi-select
    if last_selected_id == nil do
      handle_multi_photo_select(photo_id, socket)
    else
      # Get all filtered photos from DB
      all_photos = socket.assigns.filtered_photos

      # Apply the same filtering logic that the gallery component uses to get visible photos
      grouped_photos = Enum.group_by(all_photos, & &1.group)

      visible_photos =
        Enum.filter(all_photos, fn photo ->
          photo.group == nil or
            !Map.get(socket.assigns.collapse_group_exceptions, photo.group, socket.assigns.collapse_groups) or
            photo == List.first(grouped_photos[photo.group])
        end)

      # Find indices of last selected and newly clicked photos in the VISIBLE list
      last_index = Enum.find_index(visible_photos, &(to_string(&1.id) == last_selected_id))
      current_index = Enum.find_index(visible_photos, &(to_string(&1.id) == photo_id))

      case {last_index, current_index} do
        {nil, _} ->
          # Last selected photo not in current view, fall back to multi-select
          handle_multi_photo_select(photo_id, socket)
        {_, nil} ->
          # Current photo not found, shouldn't happen but fall back
          handle_multi_photo_select(photo_id, socket)
        {start_idx, end_idx} ->
          # Get the range of VISIBLE photos between start and end (inclusive)
          {min_idx, max_idx} = if start_idx <= end_idx, do: {start_idx, end_idx}, else: {end_idx, start_idx}
          range_visible_photos = Enum.slice(visible_photos, min_idx..max_idx)

          # For any photo in the range that belongs to a collapsed group,
          # we need to include ALL photos from that group
          photos_to_select = expand_collapsed_groups(range_visible_photos, grouped_photos, socket)

          # Merge with existing selection
          current_selected_ids = Enum.map(socket.assigns.selected_photos, & &1.id)
          new_photo_ids = Enum.map(photos_to_select, & &1.id)
          merged_selection = (current_selected_ids ++ new_photo_ids) |> Enum.uniq()

          {:noreply,
           push_patch(socket,
             to:
               Util.build_url(
                 socket.assigns.folder,
                 merged_selection,
                 socket.assigns.tags,
                 socket.assigns.exclude_tags,
                 socket.assigns.is_admin,
                 nil,
                 socket.assigns.sort
               )
           )
           |> assign(:last_selected_photo_id, photo_id)}
      end
    end
  end

  # Expand collapsed groups: for each photo in the range that belongs to a collapsed group,
  # include all photos from that group
  defp expand_collapsed_groups(range_photos, grouped_photos, socket) do
    Enum.flat_map(range_photos, fn photo ->
      if photo.group != nil do
        is_collapsed = Map.get(socket.assigns.collapse_group_exceptions, photo.group, socket.assigns.collapse_groups)

        if is_collapsed do
          # This group is collapsed, so include all photos from the group
          Map.get(grouped_photos, photo.group, [photo])
        else
          # Group is not collapsed, just include this photo
          [photo]
        end
      else
        # Not in a group, just include this photo
        [photo]
      end
    end)
    |> Enum.uniq_by(& &1.id)
  end

  def refresh_tags(socket) do
    all_tags = Gallery.list_tags() |> Enum.map(& &1.name)

    nav_tags =
      case socket.assigns.folder do
        nil -> all_tags
        _ -> Gallery.list_tags_by_folder(socket.assigns.folder) |> Enum.map(& &1.name)
      end

    socket
    |> assign(:all_tags, all_tags)
    |> assign(:nav_tags, nav_tags)
  end

  def refresh_selected_photos(socket) do
    selected_photos =
      socket.assigns.selected_photos
      |> Enum.map(& &1.id)
      |> Gallery.get_photos_by_ids(include_private: socket.assigns.is_admin)
      |> Repo.preload([:tags, :folder, cross_listings: :folder, original_photo: :folder])

    update_photo_form =
      case selected_photos do
        [photo] -> photo
        _ -> %Photo{}
      end
      |> Gallery.update_photo_changeset()
      |> Component.to_form()

    socket
    |> assign(selected_photos: selected_photos)
    |> assign(update_photo_form: update_photo_form)
  end

  def refresh_filtered_photos(socket) do
    is_admin = socket.assigns.is_admin
    sort = socket.assigns.sort

    filtered_photos =
      case {socket.assigns.folder, socket.assigns.tags, socket.assigns.exclude_tags} do
        {nil, [], []} ->
          Gallery.list_photos(include_private: is_admin, sort: sort)

        {nil, tags, exclude_tags} ->
          Gallery.list_photos_by_tags(%{include: tags, exclude: exclude_tags},
            include_private: is_admin,
            sort: sort
          )

        {folder, [], []} ->
          Gallery.list_photos_by_folder(folder, include_private: is_admin, sort: sort)

        {folder, tags, exclude_tags} ->
          Gallery.list_photos_by_folder_and_tags(folder, %{include: tags, exclude: exclude_tags},
            include_private: is_admin,
            sort: sort
          )
      end

    # |> Repo.preload([:tags, :folder, cross_listings: :folder, original_photo: :folder])

    # filtered_photos
    # |> Enum.flat_map(& &1.tags)
    recommended_tags =
      case socket.assigns.tags do
        [] ->
          socket.assigns.nav_tags

        _ ->
          # filtered_photos
          # |> Repo.preload([:tags, :folder, cross_listings: :folder, original_photo: :folder])
          # |> Enum.flat_map(& &1.tags)
          Gallery.list_tags_by_photos(filtered_photos |> Enum.map(& &1.id))
          |> Enum.map(& &1.name)
      end

    socket
    |> assign(
      :filtered_photos,
      filtered_photos
      |> Enum.map(&simplify_photo/1)
    )
    |> assign(:recommended_tags, recommended_tags)
  end

  ## Event Handlers

  def handle_event("toggle_multiselect", _params, socket) do
    {:noreply, assign(socket, :multiselect_active, !socket.assigns.multiselect_active)}
  end

  def handle_event("toggle_visibility_outlines", _params, socket) do
    {:noreply, assign(socket, :show_visibility_outlines, !socket.assigns.show_visibility_outlines)}
  end

  def handle_event("toggle_collapse_groups", _params, socket) do
    {:noreply,
     assign(socket, :collapse_groups, !socket.assigns.collapse_groups)
     |> assign(:collapse_group_exceptions, %{})}
  end

  def handle_event("toggle_collapse_single_group", %{"photo_group" => photo_group}, socket) do
    {:noreply,
     assign(
       socket,
       :collapse_group_exceptions,
       Map.update(
         socket.assigns.collapse_group_exceptions,
         photo_group,
         !socket.assigns.collapse_groups,
         &(!&1)
       )
     )}
  end

  # For when photo represents a collapsed group
  # This version, with photo_group, must be listed first or the group event will fall through incorrectly
  def handle_event(
        "select_gallery_photo",
    %{"photo_group" => photo_group, "photo_id" => photo_id, "ctrl_key_pressed" => ctrl_key_pressed, "shift_key_pressed" => shift_key_pressed},
        socket
      ) do
    # Handle shift-click by delegating to range select handler
    if shift_key_pressed do
      handle_shift_range_select(photo_id, socket)
    else
      handle_photo_group_select(photo_id, photo_group, ctrl_key_pressed, socket)
    end
  end

  # Holding ctrl while clicking a photo will select multiple
  def handle_event(
        "select_gallery_photo",
    %{"ctrl_key_pressed" => ctrl_key_pressed, "shift_key_pressed" => shift_key_pressed, "photo_id" => photo_id},
        socket
      ) do
    cond do
      shift_key_pressed ->
        handle_shift_range_select(photo_id, socket)
      ctrl_key_pressed or socket.assigns.multiselect_active ->
        handle_multi_photo_select(photo_id, socket)
      true ->
        handle_single_photo_select(photo_id, socket)
    end
  end

  def handle_event("add_tag", %{"photo_id" => photo_id, "tag" => tag}, socket) do
    photo = Gallery.get_photo!(photo_id, include_private: socket.assigns.is_admin)
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag)

    socket =
      case tag in socket.assigns.all_tags do
        true -> socket
        false -> assign(socket, :all_tags, [tag | socket.assigns.all_tags])
      end

    {:noreply,
     socket
     |> refresh_tags()
     |> refresh_selected_photos()}
  end

  def handle_event("remove_tag", %{"photo_id" => photo_id, "tag" => tag}, socket) do
    photo = Gallery.get_photo!(photo_id, include_private: socket.assigns.is_admin)
    {:ok, _} = Gallery.remove_tag_from_photo(photo, tag)

    {:noreply,
     socket
     |> refresh_tags()
     |> refresh_selected_photos()}
  end

  def handle_event("add_tag_bulk", %{"tag" => tag}, socket) do
    selected_photos = socket.assigns.selected_photos

    Enum.each(selected_photos, fn photo ->
      {:ok, _} = Gallery.add_tag_to_photo(photo, tag)
    end)

    {:noreply,
     socket
     |> refresh_tags()
     |> refresh_selected_photos()}
  end

  def handle_event("remove_tag_bulk", %{"tag" => tag}, socket) do
    selected_photos = socket.assigns.selected_photos

    Enum.each(selected_photos, fn photo ->
      {:ok, _} = Gallery.remove_tag_from_photo(photo, tag)
    end)

    {:noreply,
     socket
     |> refresh_tags()
     |> refresh_selected_photos()}
  end

  def handle_event("set_group_bulk", %{"group" => group}, socket) do
    selected_photos = socket.assigns.selected_photos

    Enum.each(selected_photos, fn photo ->
      {:ok, _} = Gallery.update_photo(photo, %{"group" => group})
    end)

    {:noreply,
     socket
     |> refresh_selected_photos()
     |> refresh_filtered_photos()}
  end

  def handle_event("form_group_from_selected", _params, socket) do
    selected_photos = socket.assigns.selected_photos

    # If some of the selected photos have a group, and they all have the same group, use that group
    # Otherwise, use the current timestamp as the group
    existing_groups =
      Enum.map(selected_photos, & &1.group) |> Enum.uniq() |> Enum.reject(&is_nil/1)

    group =
      case existing_groups do
        [single_group] -> single_group
        _ -> DateTime.utc_now() |> DateTime.to_iso8601()
      end

    Enum.each(selected_photos, fn photo ->
      {:ok, _} = Gallery.update_photo(photo, %{"group" => group})
    end)

    {:noreply,
     socket
     |> refresh_selected_photos()
     |> refresh_filtered_photos()}
  end

  @doc """
  Handles bulk visibility changes for multiple selected photos.
  """
  def handle_event("set_visibility_bulk", %{"is_public" => is_public}, socket) do
    selected_photos = socket.assigns.selected_photos
    is_public_bool = is_public == "true"

    Enum.each(selected_photos, fn photo ->
      {:ok, _} = Gallery.update_photo(photo, %{"is_public" => is_public_bool})
    end)

    {:noreply,
     socket
     |> refresh_selected_photos()
     |> refresh_filtered_photos()}
  end

  def handle_event("update_photo", %{"photo_id" => id, "photo" => photo_params}, socket) do
    photo = Gallery.get_photo!(id, include_private: socket.assigns.is_admin)
    result = Gallery.update_photo(photo, photo_params)
    is_admin = socket.assigns.is_admin

    case result do
      {:ok, _photo} ->
        {:noreply,
         assign(socket, :all_folders, Gallery.list_folders(include_private: is_admin))
         |> refresh_selected_photos()
         |> refresh_filtered_photos()
         |> put_flash(:info, "Photo updated successfully.")}

      {:error, :cross_listing_exists_in_target_folder} ->
        target_folder = Repo.get!(PhotoTagger.Gallery.Folder, photo_params["folder_id"])
        {:noreply,
         socket
         |> put_flash(:error, "Cannot move: this photo is cross-listed in #{target_folder.name}. Remove the cross-listing first.")}

      {:error, :cross_listing_in_same_folder_as_original} ->
        target_folder = Repo.get!(PhotoTagger.Gallery.Folder, photo_params["folder_id"])
        {:noreply,
         socket
         |> put_flash(:error, "Cannot move cross-listing to #{target_folder.name}: the original photo is already in that folder.")}

      {:error, failed_op, failed_value, _changeset} ->
        {:noreply,
         socket
         |> refresh_selected_photos()
         |> put_flash(
           :error,
           "Failed to update photo. Error #{failed_value} in step #{failed_op}."
         )}
    end
  end

  def handle_event("delete_photo", %{"photo_id" => id}, socket) do
    photo = Gallery.get_photo!(id, include_private: socket.assigns.is_admin)
    {:ok, _photo} = Gallery.delete_photo(photo)

    {:noreply,
     socket
     |> assign(:all_folders, Gallery.list_folders(include_private: socket.assigns.is_admin))
     |> refresh_tags()
     |> refresh_filtered_photos()
     |> push_patch(
       to:
         Util.build_url(
           socket.assigns.folder,
           [],
           socket.assigns.tags,
           socket.assigns.exclude_tags,
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort
         )
     )
     |> put_flash(:info, "Photo deleted successfully.")}
  end

  def handle_event("delete_photo_bulk", _params, socket) do
    selected_photos = socket.assigns.selected_photos

    Enum.each(selected_photos, fn photo ->
      {:ok, _photo} = Gallery.delete_photo(photo)
    end)

    {:noreply,
     socket
     |> assign(:all_folders, Gallery.list_folders(include_private: socket.assigns.is_admin))
     |> refresh_tags()
     |> refresh_filtered_photos()
     |> push_patch(
       to:
         Util.build_url(
           socket.assigns.folder,
           [],
           socket.assigns.tags,
           socket.assigns.exclude_tags,
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort
         )
     )
     |> put_flash(:info, "Photos deleted successfully.")}
  end

  def handle_event("create_cross_listing", %{"photo_id" => photo_id, "folder_id" => folder_id}, socket) do
    photo = Gallery.get_photo!(photo_id, include_private: true)
    photo = Repo.preload(photo, [:folder, :tags, :cross_listings, original_photo: :folder])

    case Gallery.create_cross_listing(photo, String.to_integer(folder_id)) do
      {:ok, cross_listing} ->
        cross_listing = Repo.preload(cross_listing, :folder)
        # Reload the photo to get updated cross_listings
        _updated_photo = Gallery.get_photo!(photo.id, include_private: true)
          |> Repo.preload([:folder, :tags, :cross_listings, original_photo: :folder])

        {:noreply,
         socket
         |> put_flash(:info, "Photo cross-listed to #{cross_listing.folder.name}")
         |> assign(:all_folders, Gallery.list_folders(include_private: socket.assigns.is_admin))
         |> refresh_selected_photos()
         |> refresh_filtered_photos()}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create cross-listing")}
    end
  end

  def handle_event("remove_cross_listing", %{"photo_id" => photo_id}, socket) do
    photo = Gallery.get_photo!(photo_id, include_private: true) |> Repo.preload(:folder)
    folder_name = photo.folder.name

    case Gallery.remove_cross_listing(photo) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cross-listing removed")
         |> push_patch(to: Util.build_url(folder_name, [], socket.assigns.tags, socket.assigns.exclude_tags, socket.assigns.is_admin))}

      {:error, :not_a_cross_listing} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot remove - this is not a cross-listing")}
    end
  end

  def handle_event("create_cross_listing_bulk", %{"folder_id" => folder_id}, socket) do
    target_folder_id = String.to_integer(folder_id)

    # Filter to only original photos (skip cross-listings)
    originals = Enum.reject(socket.assigns.selected_photos, &Gallery.is_cross_listing?/1)

    results = Enum.map(originals, fn photo ->
      Gallery.create_cross_listing(photo, target_folder_id)
    end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    error_count = Enum.count(results, &match?({:error, _}, &1))

    socket =
      case {success_count, error_count} do
        {0, _} ->
          put_flash(socket, :error, "No cross-listings created (photos may already exist in target folder)")
        {_, 0} ->
          put_flash(socket, :info, "Created #{success_count} cross-listing(s)")
        {_, _} ->
          put_flash(socket, :info, "Created #{success_count} cross-listing(s), #{error_count} skipped")
      end

    {:noreply,
     socket
     |> assign(:all_folders, Gallery.list_folders(include_private: socket.assigns.is_admin))
     |> refresh_selected_photos()
     |> refresh_filtered_photos()}
  end

  def handle_event("zoom_in", _params, socket) do
    {:noreply, assign(socket, :zoom_level, clamp(socket.assigns.zoom_level + 1, -9, 9))}
  end

  def handle_event("zoom_out", _params, socket) do
    {:noreply, assign(socket, :zoom_level, clamp(socket.assigns.zoom_level - 1, -9, 9))}
  end

  def handle_event("change_sort", %{"sort" => sort}, socket) do
    sort_atom = case sort do
      "date" -> :date
      "manual" -> :manual
      _ -> :manual
    end

    {:noreply,
     push_patch(socket,
       to:
         Util.build_url(
           socket.assigns.folder,
           socket.assigns.selected_photo_ids,
           socket.assigns.tags,
           socket.assigns.exclude_tags,
           socket.assigns.is_admin,
           nil,
           sort_atom
         )
     )}
  end

  def handle_event("change_folder", %{"folder" => folder}, socket) do
    folder =
      case folder do
        "" -> nil
        _ -> folder
      end

    {:noreply,
     push_patch(socket, to: Util.build_url(folder, [], [], [], socket.assigns.is_admin, nil, socket.assigns.sort))}
  end

  def handle_event("toggle_tag", %{"tag" => tag}, socket) do
    new_tags =
      case tag in socket.assigns.tags do
        true -> Enum.filter(socket.assigns.tags, fn t -> t != tag end)
        false -> socket.assigns.tags ++ [tag]
      end

    {:noreply,
     push_patch(socket,
       to:
         Util.build_url(
           socket.assigns.folder,
           socket.assigns.selected_photo_ids,
           new_tags,
           Enum.filter(socket.assigns.exclude_tags, fn t -> t != tag end),
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort
         )
     )}
  end

  def handle_event("link_tag", %{"tag" => tag}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Util.build_url(
           socket.assigns.folder,
           socket.assigns.selected_photo_ids,
           [tag],
           Enum.filter(socket.assigns.exclude_tags, fn t -> t != tag end),
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort
         )
     )}
  end

  def handle_event("toggle_exclude_tag", %{"tag" => tag}, socket) do
    new_exclude_tags =
      case tag in socket.assigns.exclude_tags do
        true -> Enum.filter(socket.assigns.exclude_tags, fn t -> t != tag end)
        false -> socket.assigns.exclude_tags ++ [tag]
      end

    {:noreply,
     push_patch(socket,
       to:
         Util.build_url(
           socket.assigns.folder,
           socket.assigns.selected_photo_ids,
           Enum.filter(socket.assigns.tags, fn t -> t != tag end),
           new_exclude_tags,
           socket.assigns.is_admin,
           nil,
           socket.assigns.sort
         )
     )}
  end

  def handle_event("change_page", %{"pg" => pg}, socket) do
    pg = Util.safe_integer_parse(pg, 1)

    {:noreply,
     assign(socket, :pg, pg) |> push_event("scroll_to_top", %{selector: "#gallery-section"})}
  end

  ## Utility functions

  defp delete_button_text(photo) do
    case Enum.empty?(photo.cross_listings) do
      true -> "Delete"
      false -> "Delete photo and all cross-listings"
    end
  end

  defp delete_confirmation_message(photo) do
    case Enum.empty?(photo.cross_listings) do
      true -> "Are you sure you want to permanently delete this photo?"
      false ->
        count = length(photo.cross_listings)
        "This will permanently delete this photo and #{count} cross-listing(s). Continue?"
    end
  end

  defp available_cross_list_folders(photo, all_folders) do
    existing_folder_ids = MapSet.new([photo.folder_id | Enum.map(photo.cross_listings, & &1.folder_id)])
    Enum.reject(all_folders, &(&1.id in existing_folder_ids))
  end

  def member_by_id?(enumerable, %{id: id}) do
    Enum.any?(enumerable, fn
      %{id: ^id} -> true
      _ -> false
    end)
  end

  def clamp(x, min, max), do: min(max(x, min), max)

  # Keep only the values which are used by the UI
  def simplify_photo(photo), do: Map.take(photo, [:id, :name, :group, :image, :folder, :is_public, :original_photo_id, :original_photo])
end

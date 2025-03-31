defmodule PhotoTaggerWeb.GalleryLive.Main do
  use PhotoTaggerWeb, :live_view

  alias Phoenix.Component
  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo
  alias PhotoTagger.Uploaders.ImageUploader
  alias PhotoTaggerWeb.HtmlHelpers
  import PhotoTaggerWeb.Components.Accordion

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-7 gap-4 h-full">
      <div id="folders-section" class="col-span-2 lg:col-span-1 overflow-y-auto">
        <.folders
          all_folders={@all_folders}
          all_tags={@all_tags}
          folder={@folder}
          tags={@tags}
          recommended_tags={@recommended_tags}
        />
      </div>
      <div id="gallery-section" class="col-span-3 lg:col-span-4 overflow-y-auto">
        <.gallery_header
          item_count={Enum.count(@filtered_photos)}
          multiselect_active={@multiselect_active}
          collapse_groups={@collapse_groups}
        />
        <div>
          <.gallery
            photos={@filtered_photos}
            folder={@folder}
            tags={@tags}
            selected_photos={@selected_photos}
            collapse_groups={@collapse_groups}
          />
        </div>
      </div>
      <div id="photo-section" class="col-span-2 overflow-y-auto">
        <%= case @selected_photos do %>
          <% [photo] -> %>
            <.photo
              photo={photo}
              folder={@folder}
              tags={@tags}
              recommended_tags={@recommended_tags}
              update_photo_form={@update_photo_form}
            />
          <% [] -> %>
            <p class="text-center">Select a photo to view details</p>
          <% _ -> %>
            <.multi_photo_selection
              photos={@selected_photos}
              folder={@folder}
              tags={@tags}
              all_tags={@all_tags}
              recommended_tags={@recommended_tags}
            />
        <% end %>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:all_folders, Gallery.list_folders_include_tags())
      |> assign(:all_tags, Gallery.list_tags())
      |> assign(:multiselect_active, false)
      |> assign(:collapse_groups, false)
      #  |> assign(%{
      #    folder: nil,
      #    tags: [],
      #    filtered_photos: [],
      #    selected_photos: [],
      #    recommended_tags: [],
      #    update_photo_form: Gallery.update_photo_changeset(%Photo{}) |> Component.to_form()
      #  })
    }
  end

  def handle_params(params, _session, socket) do
    folder = Map.get(params, "folder")
    tags = Map.get(params, "query_tags", [])
    photo_id = Map.get(params, "photo_id")
    selected_photo_ids = Map.get(params, "selected_photos", [])

    expanded_state =
      expand_state(socket, %{
        folder: folder,
        tags: tags,
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
        do:
          push_event(socket, "scroll_into_view", %{
            selector: "##{folder_accordion_id(expanded_state.folder)}"
          }),
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

  def build_url(folder, selected_photos, tags) do
    {photo_id, selected_photo_ids} =
      case selected_photos do
        [photo] -> {photo.id, []}
        photos -> {nil, Enum.map(photos, & &1.id)}
      end

    uri = URI.new!("/")
    uri = if(folder, do: URI.append_path(uri, "/folders/#{folder}"), else: uri)
    uri = if(photo_id, do: URI.append_path(uri, "/photos/#{photo_id}"), else: uri)

    query =
      %{}
      |> Map.put(:query_tags, tags)
      |> Map.put(:selected_photos, selected_photo_ids)
      |> Plug.Conn.Query.encode()

    uri =
      case query do
        "" -> uri
        _ -> URI.append_query(uri, query)
      end

    URI.to_string(uri)
  end

  def expand_state(
        socket,
        %{
          folder: folder,
          tags: tags,
          # This id comes from the url path
          photo_id: photo_id,
          # These come from url query params
          selected_photo_ids: selected_photo_ids
        }
      ) do
    prev_folder = Map.get(socket.assigns, :folder)
    prev_tags = Map.get(socket.assigns, :tags, [])
    prev_filtered_photos = Map.get(socket.assigns, :filtered_photos, nil)

    filtered_photos =
      case {folder, tags, prev_filtered_photos} do
        # If the folder and tags are unchanged, and we have previously cached filtered photos, use them without querying the database
        {^prev_folder, ^prev_tags, prev_filtered_photos} when is_list(prev_filtered_photos) ->
          prev_filtered_photos

        {nil, [], _} ->
          Gallery.list_photos()
          |> Repo.preload(:tags)

        {nil, tags, _} ->
          Gallery.list_photos_by_all_tags(tags)
          |> Repo.preload(:tags)

        {folder, [], _} ->
          Gallery.list_photos_by_folder(folder)
          |> Repo.preload(:tags)

        {folder, tags, _} ->
          Gallery.list_photos_by_folder_and_tags(folder, tags)
          |> Repo.preload(:tags)
      end

    prev_selected_photos = Map.get(socket.assigns, :selected_photos, nil)

    prev_selected_photo_ids =
      case Map.get(socket.assigns, :selected_photos, nil) do
        nil -> nil
        photos -> Enum.map(photos, & &1.id)
      end

    new_selected_photo_ids =
      [photo_id | selected_photo_ids]
      |> Enum.filter(&(&1 != nil))

    selected_photos =
      case {new_selected_photo_ids, prev_selected_photos} do
        # If the selected photo ids have not changed, and we have cached selected photos, use them without querying the database
        {^prev_selected_photo_ids, prev_selected_photos} when is_list(prev_selected_photos) ->
          prev_selected_photos

        # Otherwise, selections have changed, query them from the database
        {_, _} ->
          new_selected_photo_ids
          |> Enum.map(&Gallery.get_photo!(&1))
          |> Repo.preload(:tags)
      end

    # If filtered photos have not changed, use cached recommended tags
    recommended_tags =
      case filtered_photos do
        ^prev_filtered_photos ->
          Map.get(socket.assigns, :recommended_tags, [])

        _ ->
          Enum.reduce(filtered_photos, MapSet.new(), fn photo, acc ->
            MapSet.union(acc, MapSet.new(photo.tags))
          end)
          |> MapSet.to_list()
          |> Enum.sort_by(&String.downcase(&1.name))
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
      filtered_photos: filtered_photos,
      selected_photos: selected_photos,
      recommended_tags: recommended_tags,
      update_photo_form: update_photo_form
    }
  end

  attr(:folder, :string, default: nil)
  attr(:selected_photos, :list, default: [])
  attr(:tags, :list, default: [])
  attr(:toggled_tag, :string, required: true)
  attr(:class, :string, default: "")
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

    assigns =
      assign(assigns, :href, build_url(assigns.folder, assigns.selected_photos, tags_list))

    ~H"""
    <.toggle_link
      selected={@toggled_tag in @tags}
      href={@href}
      class={@class}
    >
      {render_slot(@inner_block)}
    </.toggle_link>
    """
  end

  def folder_accordion_id(folder) do
    if folder do
      HtmlHelpers.escape_html_id("accordion-#{folder}")
    else
      "accordion-all-folders"
    end
  end

  attr(:nav_tags, :list, required: true)
  attr(:recommended_tags, :list, required: true)
  attr(:nav_folder, :string, default: nil)
  attr(:current_folder, :string, default: nil)
  attr(:tags, :list, default: [])

  def folder_nav_item(assigns) do
    recommended_tag_names = Enum.map(assigns.recommended_tags, & &1.name)

    {recommended_nav_tags, other_nav_tags} =
      Enum.split_with(assigns.nav_tags, &(&1 in recommended_tag_names))

    assigns =
      assigns
      |> assign(:is_current_folder, assigns.current_folder == assigns.nav_folder)
      |> assign(:recommended_nav_tags, recommended_nav_tags)
      |> assign(:other_nav_tags, other_nav_tags)

    ~H"""
    <li>
      <.accordion id={folder_accordion_id(@nav_folder)}>
        <:trigger>
          <%!-- <p class="text-left data-[selected]:font-bold" data-selected={@is_current_folder}>
            {if(@nav_folder, do: @nav_folder, else: "All folders")}
          </p> --%>
          <p class="text-left">
            <.link
                class="data-[selected]:font-bold"
                data-selected={Enum.empty?(@tags) && @is_current_folder}
                patch={build_url(@nav_folder, [], [])}
              >
              {if(@nav_folder, do: @nav_folder, else: "All folders")}
            </.link>
          </p>
        </:trigger>
        <:panel default_expanded={@is_current_folder}>
          <div class="divide-y divide-zinc-300 my-2 pl-2 list-none">
            <%= if not Enum.empty?(@recommended_nav_tags) do %>
              <ul class="flex flex-wrap my-2">
                <%= for tag <- Enum.sort_by(@recommended_nav_tags, fn tag ->
                    cond do
                      tag in @tags -> 0 # show currently selected tags first
                      # tag in @recommended_tag_names -> 1 # then recommended tags
                      true -> 2 # then other tags
                    end
                  end) do %>
                  <li class="mr-2 flex items-center">
                      <.toggle_tag_button folder={@nav_folder} tags={@tags} toggled_tag={tag}>
                        {tag}
                      </.toggle_tag_button>
                  </li>
                <% end %>
              </ul>
            <% end %>
            <%= if not Enum.empty?(@other_nav_tags) do %>
              <ul class="flex flex-wrap py-2">
                <%= for tag <- @other_nav_tags do %>
                  <li>
                    <%!-- <.toggle_link selected={false}
                      class="text-gray-500 border-gray-500"
                      href={build_url(@nav_folder, [], [tag])} >
                      {tag}
                    </.toggle_link> --%>
                    <.link class="text-zinc-500 mr-2 my-1" patch={build_url(@nav_folder, [], [tag])} >
                      {tag}
                    </.link>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </:panel>
      </.accordion>
    </li>
    """
  end

  attr(:all_folders, :list, required: true)
  attr(:all_tags, :list, required: true)
  attr(:recommended_tags, :list, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])

  def folders(assigns) do
    ~H"""
    <div>
      <h2 class="hidden lg:block">Folders</h2>
      <ul class="space-y-2 mt-2 text-sm md:text-base">
        <.folder_nav_item
          current_folder={@folder}
          nav_tags={Enum.map(@all_tags, & &1.name)}
          recommended_tags={@recommended_tags}
          tags={@tags}
        />
        <%= for folder <- @all_folders do %>
          <.folder_nav_item
            current_folder={@folder}
            nav_folder={folder.name}
            nav_tags={folder.tags}
            recommended_tags={@recommended_tags}
            tags={@tags}
          />
        <% end %>
      </ul>
    </div>
    """
  end

  attr(:item_count, :integer, required: true)
  attr(:multiselect_active, :boolean, required: true)
  attr(:collapse_groups, :boolean, required: true)

  def gallery_header(assigns) do
    ~H"""
    <div class="flex flex-row-reverse flex-wrap items-center sticky top-0 bg-white z-50">
      <div class="flex-none mr-3 lg-ml-3">
        <p class="font-bold">{"#{@item_count}"}<span class="hidden md:inline">{" items"}</span></p>
      </div>
      <div class="flex-none pr-3">
        <.toggle_button
          selected={@multiselect_active}
          phx-click="toggle_multiselect"
          class="flex items-center pl-3 pr-3"
        >
          <.icon name="hero-squares-plus" class="hero-squares-plus-mini lg:hero-squares-plus my-1 lg:my-0 w-4 h-4 lg:w-5 lg:h-5" />
          <span class="sr-only lg:not-sr-only lg:ml-1">
            Multiselect
          </span>
        </.toggle_button>
      </div>
      <div class="flex-none pl-3 pr-3">
        <.toggle_button
          selected={@collapse_groups}
          phx-click="toggle_collapse_groups"
          class="flex items-center pl-3 pr-3"
        >
          <.icon name="hero-square-3-stack-3d" class="hero-square-3-stack-3d-mini lg:hero-square-3-stack-3d my-1 lg:my-0 w-4 h-4 lg:w-5 lg:h-5" />
          <span class="sr-only lg:not-sr-only lg:ml-1">
            Collapse groups
          </span>
        </.toggle_button>
      </div>
    </div>
    """
  end

  attr(:photos, :list, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])
  attr(:selected_photos, :list, default: [])
  attr(:collapse_groups, :boolean, default: false)

  def gallery(assigns) do
    grouped_photos = Enum.group_by(assigns.photos, & &1.group)
    assigns = assign(assigns, :grouped_photos, grouped_photos)

    assigns =
      case assigns.collapse_groups do
        false ->
          assigns

        true ->
          assign(
            assigns,
            :photos,
            # Filter out photos that are in a group, excepting the first in any group
            Enum.filter(assigns.photos, fn photo ->
              photo.group == nil or photo == List.first(grouped_photos[photo.group])
            end)
          )
      end

    ~H"""
    <div>
      <ul class="flex flex-wrap gap-4 p-6">
        <%= for photo <- @photos do %>
          <% represents_group = @collapse_groups and photo.group != nil and Enum.count(@grouped_photos[photo.group]) > 1 %>
          <li class="w-40 h-40">
            <button
              id={"gallery-photo-button-#{photo.id}"}
              class="h-full w-full relative
                data-[selected]:outline outline-4 outline-offset-2 outline-blue-400
                phx-click-loading:outline phx-click-loading:outline-blue-200"
              data-selected={member_by_id?(@selected_photos, photo)}
              phx-click={if(represents_group, do: "select_gallery_group", else: "select_gallery_photo")}
              phx-value-photo_id={photo.id}
              phx-value-photo_group={photo.group}
            >
              <%!-- use object-cover for cropped squares, and object-contain for shrinked full images --%>
              <img
                class="w-40 h-40 object-cover"
                alt={photo.name}
                src={ImageUploader.url({photo.image, photo}, :small)}
              />
              <%= if represents_group do %>
                <div class="w-40 h-40 -z-10 absolute left-1 bottom-1 bg-gray-500" />
                <div class="w-40 h-40 -z-20 absolute left-2 bottom-2 bg-gray-400" />
              <% end %>
            </button>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  attr(:photo, :map, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])
  attr(:recommended_tags, :list, default: [])
  attr(:update_photo_form, :map, required: true)

  def photo(assigns) do
    ~H"""
    <.list>
      <%!-- On medium screens and above, sticky the image section to the top --%>
      <:item title="Image" class="max-h-[40vh] lg:sticky lg:top-0 lg:bg-white lg:border-b lg:border-zinc-100 lg:mb-4 lg:z-10">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)} target="_blank">
          <img class="object-contain h-full" img={@photo.name} src={ImageUploader.url({@photo.image, @photo}, :small)} />
        </.link>
      </:item>
      <:item title="Folder">
        <.link
          class="data-[active]:font-bold"
          patch={build_url(@photo.folder, [@photo], @tags)}
          data-active={@folder == @photo.folder}
        >
          {@photo.folder}
        </.link>
      </:item>
      <:item title="Tags">
        <ul class="flex flex-wrap">
          <%= for tag <- @photo.tags do %>
            <li class="mr-2 flex items-center">
              <.toggle_tag_button
                folder={@folder}
                selected_photos={[@photo]}
                tags={@tags}
                toggled_tag={tag.name}
              >
                {tag.name}
              </.toggle_tag_button>
              <.form
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
        <div class="mt-2">
          <.form for={Component.to_form(%{"tag" => "", "photo_id" => @photo.id})} phx-submit="add_tag">
            <input class="hidden" type="text" name="photo_id" value={@photo.id} />
            <div class="flex items-center space-x-4">
              <%!-- TODO: convert this simple inline form to a component --%>
              <%!-- <.label for="add_any_tag">Add tag</.label> --%>
              <input
                type="text"
                name="tag"
                id="add_any_tag"
                Placeholder="Add tag"
                class="block max-w-64 rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
              />
              <.button type="submit">Submit</.button>
            </div>
          </.form>
        </div>
        <div class="flex flex-wrap mt-2">
          <%= for tag <- @recommended_tags do %>
            <%= if tag not in @photo.tags do %>
              <div class="mr-2">
                <.form
                  for={Component.to_form(%{"tag" => tag.name, "photo_id" => @photo.id})}
                  phx-submit="add_tag"
                >
                  <input class="hidden" type="text" name="photo_id" value={@photo.id} />
                  <input class="hidden" type="text" name="tag" value={tag.name} />
                  <button
                    class="border border-blue-600 rounded-full hover:bg-blue-100 px-1 my-1 text-blue-600 hover:text-blue-800"
                    type="submit"
                  >
                    {tag.name}
                  </button>
                </.form>
              </div>
            <% end %>
          <% end %>
        </div>
      </:item>
      <:item title="Download file">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)} download>
          {@photo.name}
        </.link>
      </:item>
      <:item title="Edit">
        <.form for={@update_photo_form} id="update-photo-form" phx-submit="update_photo">
          <input class="hidden" type="text" name="photo_id" value={@update_photo_form.data.id} />
          <.input field={@update_photo_form[:name]} name="photo[name]" type="text" label="Name" />
          <.input field={@update_photo_form[:folder]} name="photo[folder]" type="text" label="Folder" />
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
          <.button class="mt-4">Save</.button>
        </.form>
      </:item>
      <:item title="Image last modified">
        <p>{@photo.image_last_modified}</p>
      </:item>
      <:item title="Delete">
        <.form
          phx-submit="delete_photo"
          for={Component.to_form(%{"photo_id" => @photo.id})}
          onsubmit="return confirm('Are you sure you want to permanently delete this photo?')"
        >
          <input class="hidden" type="text" name="photo_id" value={@photo.id} />
          <.button class="bg-red-600 hover:bg-red-900">Delete</.button>
        </.form>
      </:item>
    </.list>
    """
  end

  attr(:photos, :list, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])
  attr(:all_tags, :list, required: true)
  attr(:recommended_tags, :list, default: [])

  def multi_photo_selection(assigns) do
    {tags_to_add, tags_to_remove, tags_in_limbo} =
      Enum.reduce(assigns.all_tags, {[], [], []}, fn tag, {add, remove, limbo} ->
        case Enum.reduce(assigns.photos, {0, 0}, fn photo, {has_tag_count, missing_count} ->
               case tag in photo.tags do
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
                  src={ImageUploader.url({photo.image, photo}, :small)}
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
                for={Component.to_form(%{"tag" => tag.name})}
                phx-submit="remove_tag_bulk"
              >
                <input class="hidden" type="text" name="tag" value={tag.name} />
                <button
                  class="border border-red-600 rounded-full hover:bg-red-100 px-1 my-1 text-red-600 hover:text-red-800"
                  type="submit"
                >
                  {tag.name}
                </button>
              </.form>
            </li>
          <% end %>
        </ul>
      </:item>
      <:item title="Add tags">
        <div class="mt-4">
          <.form for={Component.to_form(%{"tag" => ""})} phx-submit="add_tag_bulk">
            <div class="flex items-center space-x-4">
              <%!-- TODO: convert this simple inline form to a component --%>
              <%!-- <.label for="add_any_tag">Add tag</.label> --%>
              <input
                type="text"
                name="tag"
                id="add_any_tag"
                Placeholder="Add tag"
                class="block max-w-64 rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
              />
              <.button type="submit">Submit</.button>
            </div>
          </.form>
        </div>
        <div class="flex flex-wrap mt-2">
          <%= for tag <- @recommended_tags do %>
            <%= if (tag not in @tags_to_remove) do %>
              <div class="mr-2">
                <.form for={Component.to_form(%{"tag" => tag.name})} phx-submit="add_tag_bulk">
                  <input class="hidden" type="text" name="tag" value={tag.name} />
                  <button
                    class="border border-blue-600 rounded-full hover:bg-blue-100 px-1 my-1 text-blue-600 hover:text-blue-800"
                    type="submit"
                  >
                    {tag.name}
                  </button>
                </.form>
              </div>
            <% end %>
          <% end %>
        </div>
      </:item>
      <:item title="Group">
        <%= if Enum.count(@groups) > 1 do %>
          <p>Photos belong to multiple groups:</p>
          <ul class="list-disc list-inside mb-2">
            <%= for group <- @groups do %>
              <li>{if group != nil, do: group, else: "No group"}</li>
            <% end %>
          </ul>
        <% end %>
        <.form for={Component.to_form(%{"group" => ""})} phx-submit="set_group_bulk">
          <div class="flex items-center space-x-4">
            <input
              type="text"
              name="group"
              id="bulk_group_input"
              Placeholder="group"
              class="block max-w-64 rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
              value={if(Enum.count(@groups) == 1, do: Enum.at(@groups, 0), else: "")}
            />
            <.button type="submit">Submit</.button>
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

    {:noreply,
     push_patch(socket, to: build_url(socket.assigns.folder, new_selection, socket.assigns.tags))}
  end

  def handle_single_photo_select(photo_id, socket) do
    {:noreply,
     push_patch(socket,
       to: build_url(socket.assigns.folder, [%{id: photo_id}], socket.assigns.tags)
     )}
  end

  def refresh_selected_photos(socket) do
    selected_photos =
      socket.assigns.selected_photos
      |> Enum.map(& &1.id)
      |> Enum.map(&Gallery.get_photo!(&1))
      |> Repo.preload(:tags)

    assign(socket, selected_photos: selected_photos)
  end

  def refresh_filtered_photos(socket) do
    filtered_photos =
      case {socket.assigns.folder, socket.assigns.tags} do
        {nil, []} -> Gallery.list_photos()
        {nil, tags} -> Gallery.list_photos_by_all_tags(tags)
        {folder, []} -> Gallery.list_photos_by_folder(folder)
        {folder, tags} -> Gallery.list_photos_by_folder_and_tags(folder, tags)
      end
      |> Repo.preload(:tags)

    assign(socket, filtered_photos: filtered_photos)
  end

  ## Event Handlers

  def handle_event("toggle_multiselect", _params, socket) do
    {:noreply, assign(socket, :multiselect_active, !socket.assigns.multiselect_active)}
  end

  def handle_event("toggle_collapse_groups", _params, socket) do
    {:noreply, assign(socket, :collapse_groups, !socket.assigns.collapse_groups)}
  end

  # Holding ctrl while clicking a photo will select multiple
  def handle_event(
        "select_gallery_photo",
        %{"ctrl_key_pressed" => ctrl_key_pressed, "photo_id" => photo_id},
        socket
      ) do
    case {ctrl_key_pressed, socket.assigns.multiselect_active} do
      {false, false} -> handle_single_photo_select(photo_id, socket)
      _ -> handle_multi_photo_select(photo_id, socket)
    end
  end

  def handle_event(
        "select_gallery_group",
        %{"photo_group" => photo_group, "ctrl_key_pressed" => ctrl_key_pressed},
        socket
      ) do
    # TODO implement, then group field in multiselect mode form, then add collapsed to url
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

    {:noreply,
     push_patch(socket,
       to: build_url(socket.assigns.folder, new_selected_photos, socket.assigns.tags)
     )}
  end

  def handle_event("add_tag", %{"photo_id" => photo_id, "tag" => tag}, socket) do
    photo = Gallery.get_photo!(photo_id)
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag)

    {:noreply,
     socket
     |> assign(:all_tags, Gallery.list_tags())
     |> assign(:all_folders, Gallery.list_folders_include_tags())
     |> refresh_selected_photos()}
  end

  def handle_event("remove_tag", %{"photo_id" => photo_id, "tag" => tag}, socket) do
    photo = Gallery.get_photo!(photo_id)
    {:ok, _} = Gallery.remove_tag_from_photo(photo, tag)

    {:noreply,
     socket
     |> assign(:all_tags, Gallery.list_tags())
     |> assign(:all_folders, Gallery.list_folders_include_tags())
     |> refresh_selected_photos()}
  end

  def handle_event("add_tag_bulk", %{"tag" => tag}, socket) do
    selected_photos = socket.assigns.selected_photos

    Enum.each(selected_photos, fn photo ->
      {:ok, _} = Gallery.add_tag_to_photo(photo, tag)
    end)

    {:noreply,
     socket
     |> assign(:all_tags, Gallery.list_tags())
     |> assign(:all_folders, Gallery.list_folders_include_tags())
     |> refresh_selected_photos()}
  end

  def handle_event("remove_tag_bulk", %{"tag" => tag}, socket) do
    selected_photos = socket.assigns.selected_photos

    Enum.each(selected_photos, fn photo ->
      {:ok, _} = Gallery.remove_tag_from_photo(photo, tag)
    end)

    {:noreply,
     socket
     |> assign(:all_tags, Gallery.list_tags())
     |> assign(:all_folders, Gallery.list_folders_include_tags())
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

  def handle_event("update_photo", %{"photo_id" => id, "photo" => photo_params}, socket) do
    photo = Gallery.get_photo!(id)
    result = Gallery.update_photo(photo, photo_params)

    case result do
      {:ok, _photo} ->
        {:noreply,
         assign(socket, :all_folders, Gallery.list_folders_include_tags())
         |> refresh_selected_photos()
         |> put_flash(:info, "Photo updated successfully.")}

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
    photo = Gallery.get_photo!(id)
    {:ok, _photo} = Gallery.delete_photo(photo)

    {:noreply,
     socket
     |> assign(:all_folders, Gallery.list_folders_include_tags())
     |> assign(:all_tags, Gallery.list_tags())
     |> refresh_filtered_photos()
     |> push_patch(to: build_url(socket.assigns.folder, [], socket.assigns.tags))
     |> put_flash(:info, "Photo deleted successfully.")}
  end

  def handle_event("delete_photo_bulk", _params, socket) do
    selected_photos = socket.assigns.selected_photos

    Enum.each(selected_photos, fn photo ->
      {:ok, _photo} = Gallery.delete_photo(photo)
    end)

    {:noreply,
     socket
     |> assign(:all_folders, Gallery.list_folders_include_tags())
     |> assign(:all_tags, Gallery.list_tags())
     |> refresh_filtered_photos()
     |> push_patch(to: build_url(socket.assigns.folder, [], socket.assigns.tags))
     |> put_flash(:info, "Photos deleted successfully.")}
  end

  ## Utility functions
  def member_by_id?(enumerable, %{id: id}) do
    Enum.any?(enumerable, fn
      %{id: ^id} -> true
      _ -> false
    end)
  end
end

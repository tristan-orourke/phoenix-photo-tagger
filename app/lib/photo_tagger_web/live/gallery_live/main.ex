defmodule PhotoTaggerWeb.GalleryLive.Main do
  use PhotoTaggerWeb, :live_view

  alias Phoenix.Component
  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo
  alias PhotoTagger.Uploaders.ImageUploader
  alias PhotoTaggerWeb.HtmlHelpers
  import PhotoTaggerWeb.Components.Accordion
  import Logger

  def render(assigns) do
    ~H"""
      <div class="grid grid-cols-7 gap-4 h-full">
        <div id="folders-section" class="col-span-1 overflow-y-auto">
          <.folders all_folders={@all_folders} all_tags={@all_tags} folder={@folder} tags={@tags} recommended_tags={@recommended_tags} />
        </div>
        <div id="gallery-section" class="col-span-4 overflow-y-auto">
          <.gallery photos={@filtered_photos} folder={@folder} tags={@tags} selected_photos={@selected_photos}/>
        </div>
        <div id="photo-section" class="col-span-2 overflow-y-auto">
          <%= case @selected_photos do %>
            <% [photo] -> %>
              <.photo photo={photo} folder={@folder} tags={@tags} recommended_tags={@recommended_tags} update_photo_form={@update_photo_form} />
            <% [] -> %>
              <p class="text-center">Select a photo to view details</p>
            <% _ -> %>
              <.multi_photo_selection photos={@selected_photos} folder={@folder} tags={@tags} all_tags={@all_tags} recommended_tags={@recommended_tags} />
          <% end %>
        </div>
      </div>
    """
  end

  def mount(_params, _session, socket) do
    #TODO: I might be able to load all_tags and all_folders here instead of handle_params.
    # Would they be updated properly after getting forms to work with live_view?
    {:ok, socket}
  end

  def handle_params(params, _session, socket) do
    folder = Map.get(params, "folder")
    tags = Map.get(params, "query_tags", [])
    photo_id = Map.get(params, "photo_id")
    selected_photo_ids = Map.get(params, "selected_photos", [])

    expanded_state = expand_state(%{folder: folder, tags: tags, photo_id: photo_id, selected_photo_ids: selected_photo_ids})

    # Reset scroll position of a section if the relevent params change
    socket = if(expanded_state.selected_photos != Map.get(socket.assigns, :selected_photos),
      do: push_event(socket, "scroll_to_top", %{selector: "#photo-section"}),
      else: socket
    )
    socket = if(expanded_state.folder != Map.get(socket.assigns, :folder),
      do: push_event(socket, "scroll_into_view", %{selector: "##{folder_accordion_id(expanded_state.folder)}"}),
      else: socket
    )
    socket = if(expanded_state.folder != Map.get(socket.assigns, :folder) or Enum.sort(expanded_state.tags) != Enum.sort(Map.get(socket.assigns, :tags, [])),
      do: push_event(socket, "scroll_to_top", %{selector: "#gallery-section"}),
      else: socket
    )

    {:noreply, assign(socket, expanded_state)}
  end

  def build_url(folder, selected_photos, tags) do
    {photo_id, selected_photo_ids} = case selected_photos do
      [photo] -> {photo.id, []}
      photos -> {nil, Enum.map(photos, &(&1.id))}
    end

    uri = URI.new!("/")
    uri = if(folder, do: URI.append_path(uri, "/folders/#{folder}"), else: uri)
    uri = if(photo_id, do: URI.append_path(uri, "/photos/#{photo_id}"), else: uri)

    tag_query = Plug.Conn.Query.encode(%{query_tags: tags})
    uri = if(!Enum.empty?(tags), do: URI.append_query(uri, tag_query), else: uri)

    selected_query = Plug.Conn.Query.encode(%{selected_photos: selected_photo_ids})
    uri = if(!Enum.empty?(selected_photo_ids), do: URI.append_query(uri, selected_query), else: uri)

    URI.to_string(uri)
  end

  def expand_state(%{folder: folder, tags: tags, photo_id: photo_id, selected_photo_ids: selected_photo_ids}) do
    filtered_photos =
      case {folder, tags} do
        {nil, []} -> Gallery.list_photos()
        {nil, tags} -> Gallery.list_photos_by_all_tags(tags)
        {folder, []} -> Gallery.list_photos_by_folder(folder)
        {folder, tags} -> Gallery.list_photos_by_folder_and_tags(folder, tags)
      end
    filtered_photos = Repo.preload(filtered_photos, :tags)

    selected_photos = [photo_id | selected_photo_ids]
      |> Enum.filter(& &1 != nil)
      |> Enum.map(& Gallery.get_photo!(&1))
      |> Repo.preload(:tags)

    recommended_tags =
      Enum.reduce(filtered_photos, MapSet.new(), fn photo, acc ->
        MapSet.union(acc, MapSet.new(photo.tags))
      end)
      |> MapSet.to_list()
      |> Enum.sort_by(& String.downcase(&1.name))

    all_folders = Gallery.list_folders_include_tags()
    all_tags = Gallery.list_tags()

    update_photo_form = case selected_photos do
        [photo] -> photo
        _ -> %Photo{} # If no photos are selected, or many are, start form changeset from a blank photo struct
      end
      |> Gallery.update_photo_changeset()
      |> Component.to_form()

    %{
      folder: folder,
      all_folders: all_folders,
      tags: tags,
      all_tags: all_tags,
      filtered_photos: filtered_photos,
      selected_photos: selected_photos,
      recommended_tags: recommended_tags,
      update_photo_form: update_photo_form,
    }
  end

  attr(:folder, :string, default: nil)
  attr(:selected_photos, :list, default: [])
  attr(:tags, :list, default: [])
  attr(:toggled_tag, :string, required: true)
  slot(:inner_block)

  def toggle_tag_button(assigns) do
    tags_list =
      cond do
        assigns.toggled_tag == nil -> assigns.tags
        assigns.toggled_tag in assigns.tags -> Enum.filter(assigns.tags, &(&1 != assigns.toggled_tag))
        true -> assigns.tags ++ [assigns.toggled_tag]
      end
    assigns = assign(assigns, :href, build_url(assigns.folder, assigns.selected_photos, tags_list))
    ~H"""
      <.link class={"
        #{@toggled_tag in @tags && "font-bold"}
        #{if(@toggled_tag in @tags, do: "bg-red-400 text-black hover:text-black", else: "bg-green-500 text-white hover:text-white")}
        rounded-full px-1 no-underline"} patch={@href}>
        <%= render_slot(@inner_block) %>
      </.link>
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
    assigns = assign(assigns, :is_current_folder, assigns.current_folder == assigns.nav_folder)
    assigns = assign(assigns, :recommended_tag_names, Enum.map(assigns.recommended_tags, & &1.name))
    ~H"""
      <li>
        <.accordion id={folder_accordion_id(@nav_folder)}>
          <:trigger>
            <p class={"text-left #{@is_current_folder && "font-bold"}"}>
              <%= if(@nav_folder, do: @nav_folder, else: "All folders") %>
            </p>
          </:trigger>
          <:panel default_expanded={@is_current_folder}>
            <ul class="list-disc list-inside">
              <li>
                <.link class={"#{Enum.empty?(@tags) && @is_current_folder && "font-bold"}"} patch={build_url(@nav_folder, [], [])}>
                  All photos
                </.link>
              </li>
              <%= for tag <- Enum.sort_by(@nav_tags, fn tag ->
                cond do
                  tag in @tags -> 0 # show currently selected tags first
                  tag in @recommended_tag_names -> 1 # then recommended tags
                  true -> 2 # then all other tags
                end
              end) do %>
                <li >
                  <.link class={"#{@is_current_folder && tag in @tags && "font-bold"}"} patch={build_url(@nav_folder, [], [tag])}><%= tag %></.link>
                  <%= if @is_current_folder and tag in @recommended_tag_names do %>
                      <.toggle_tag_button folder={@nav_folder} tags={@tags} toggled_tag={tag}><%= if(tag in @tags, do: "-", else: "+") %></.toggle_tag_button>
                    <% end %>
                </li>
              <% end %>
            </ul>
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
      <h2>Folders</h2>
      <ul class="space-y-2 mt-2">
        <.folder_nav_item current_folder={@folder} nav_tags={Enum.map(@all_tags, & &1.name)} recommended_tags={@recommended_tags} tags={@tags} />
        <%= for folder <- @all_folders do %>
          <.folder_nav_item current_folder={@folder} nav_folder={folder.name} nav_tags={folder.tags} recommended_tags={@recommended_tags} tags={@tags} />
        <% end %>
      </ul>
    </div>
    """
  end

  attr(:photos, :list, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])
  attr(:selected_photos, :list, default: [])

  def gallery(assigns) do
    ~H"""
    <div>
      <ul class="flex flex-wrap gap-4 p-6">
        <%= for photo <- @photos do %>
          <li class={"w-40 h-40 #{if(Enum.member?(@selected_photos, photo), do: "outline outline-4 outline-offset-2 outline-blue-400", else: "")}"}>
            <button class={"h-full"} phx-click="select_gallery_photo" phx-value-photo_id={photo.id}>
              <%!-- use object-cover for cropped squares, and object-contain for shrinked full images --%>
              <img
                class="w-40 h-40 object-cover"
                src={ImageUploader.url({photo.image, photo}, :small)}
              />
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
      <:item title="Image">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)} target="_blank">
          <img src={ImageUploader.url({@photo.image, @photo}, :small)} />
        </.link>
      </:item>
      <:item title="Folder">
        <.link class={"#{@folder == @photo.folder && "font-bold"}"} patch={build_url(@photo.folder, [@photo], @tags)}><%= @photo.folder %></.link>
      </:item>
      <:item title="Tags">
        <ul class="flex flex-wrap">
          <%= for tag <- @photo.tags do %>
            <li class="mr-2">
              <.toggle_tag_button folder={@folder} selected_photos={[@photo]} tags={@tags} toggled_tag={tag.name}><%= if(tag.name in @tags, do: "- ", else: "+ ") <> tag.name %></.toggle_tag_button>
              <.form class="inline" for={Component.to_form(%{"tag" => tag.name, "photo_id" => @photo.id})} phx-submit="remove_tag">
                <input class="hidden" type="text" name="photo_id" value={@photo.id} />
                <input class="hidden" type="text" name="tag" value={tag.name} />
                <button type="submit"><.icon name="hero-trash-micro" class="text-red-700 hover:text-red-900"/></button>
              </.form>
            </li>
          <% end %>
        </ul>
      </:item>
      <:item title="Add tags">
        <div>
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
              <.form for={Component.to_form(%{"tag" => tag.name, "photo_id" => @photo.id})} phx-submit="add_tag">
                <input class="hidden" type="text" name="photo_id" value={@photo.id} />
                <input class="hidden" type="text" name="tag" value={tag.name} />
                <button class="border border-blue-600 rounded-full hover:bg-blue-100 px-1 my-1 text-blue-600 hover:text-blue-800" type="submit"><%= tag.name %></button>
              </.form>
            </div>
          <% end %>
        <% end %>
        </div>
      </:item>
      <:item title="Download file">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)} download><%= @photo.name %></.link>
      </:item>
      <:item title="Edit">
        <.form for={@update_photo_form} id="update-photo-form" phx-submit="update_photo">
          <input class="hidden" type="text" name="photo_id" value={@update_photo_form.data.id} />
          <.input field={@update_photo_form[:name]} name="photo[name]" type="text" label="Name"/>
          <.input field={@update_photo_form[:folder]} name="photo[folder]" type="text" label="Folder"/>
          <.input field={@update_photo_form[:notes]} name="photo[notes]" type="textarea" label="Notes"/>
          <.input field={@update_photo_form[:description]} name="photo[description]" type="textarea" label="Description"/>
          <.button class="mt-4">Save</.button>
        </.form>
      </:item>
      <:item title="Image last modified">
        <p>{@photo.image_last_modified}</p>
      </:item>
      <:item title="Delete">
        <.form phx-submit="delete_photo"
          for={Component.to_form(%{"photo_id" => @photo.id})}
          onsubmit={"return confirm('Are you sure you want to permanently delete this photo?')"}
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
    ~H"""
    <div>
      <ul>
        <%= for photo <- @photos do %>
          <li>
            <.link patch={build_url(@folder, [photo], @tags)}>
              {photo.name}
              <%!-- <img src={ImageUploader.url({photo.image, photo}, :small)} /> --%>
            </.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def refresh_socket(socket) do
    folder = socket.assigns.folder
    tags = socket.assigns.tags
    {photo_id, selected_photo_ids} = case socket.assigns.selected_photos do
      [photo] -> {photo.id, []}
      photos -> {nil, Enum.map(photos, &(&1.id))}
    end
    expanded_state = expand_state(%{folder: folder, tags: tags, photo_id: photo_id, selected_photo_ids: selected_photo_ids})
    assign(socket, expanded_state)
  end

  # Holding ctrl while clicking a photo will select multiple
  def handle_event("select_gallery_photo", %{"ctrl_key_pressed" => true, "photo_id" => photo_id}, socket) do
    selected_photos = socket.assigns.selected_photos
    # Remove the new photo from selected_photos if it is present, otherwise add it
    new_selection = if(
      Enum.any?(selected_photos, & to_string(&1.id) == photo_id),
      do: Enum.filter(selected_photos, & to_string(&1.id) != photo_id),
      else: [%{id: photo_id} | selected_photos]
    )
    {:noreply, push_patch(socket, to: build_url(socket.assigns.folder, new_selection, socket.assigns.tags))}
  end

  def handle_event("select_gallery_photo", %{"photo_id" => photo_id}, socket) do
    Logger.debug("Selecting photo: #{photo_id}")
    {:noreply, push_patch(socket, to: build_url(socket.assigns.folder, [%{id: photo_id}], socket.assigns.tags))}
  end

  def handle_event("add_tag", %{"photo_id" => photo_id, "tag" => tag}, socket) do
    photo = Gallery.get_photo!(photo_id)
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag)
    {:noreply, refresh_socket(socket)}
  end

  def handle_event("remove_tag", %{"photo_id" => photo_id, "tag" => tag}, socket) do
    photo = Gallery.get_photo!(photo_id)
    {:ok, _} = Gallery.remove_tag_from_photo(photo, tag)
    {:noreply, refresh_socket(socket)}
  end

  def handle_event("update_photo", %{"photo_id" => id, "photo" => photo_params}, socket) do
    photo = Gallery.get_photo!(id)

    case Gallery.update_photo(photo, photo_params) do
      {:ok, _photo} ->
        {:noreply, refresh_socket(socket)
          |> put_flash(:info, "Photo updated successfully.")
        }

      {:error, failed_op, failed_value, _changeset} ->
        {:noreply, refresh_socket(socket)
          |> put_flash(:error, "Failed to update photo. Error #{failed_value} in step #{failed_op}.")
        }
    end
  end

  def handle_event("delete_photo", %{"photo_id" => id}, socket) do
    photo = Gallery.get_photo!(id)
    {:ok, _photo} = Gallery.delete_photo(photo)
    {:noreply, push_patch(socket, to: build_url(socket.assigns.folder, nil, socket.assigns.tags))
      |> put_flash(:info, "Photo deleted successfully.")
    }
  end

end

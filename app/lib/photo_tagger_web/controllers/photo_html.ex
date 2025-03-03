defmodule PhotoTaggerWeb.PhotoHTML do
  use PhotoTaggerWeb, :html
  import PhotoTaggerWeb.PhotoController, only: [build_url: 3, build_url: 4, build_cannonical_photo_url: 3, build_cannonical_photo_url: 4]
  alias PhotoTagger.Uploaders.ImageUploader

  embed_templates("photo_html/*")

  attr(:folder, :string, default: nil)
  attr(:photo, :map, default: nil)
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
    assigns = assign(assigns, :href, build_url(assigns.folder, assigns.photo, tags_list))
    ~H"""
      <.link class={"
        #{@toggled_tag in @tags && "font-bold"}
        #{if(@toggled_tag in @tags, do: "bg-red-400 text-black hover:text-black", else: "bg-green-500 text-white hover:text-white")}
        rounded-full px-1 no-underline"} href={@href}>
        <%= render_slot(@inner_block) %>
      </.link>
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
      <h2 class>Folders</h2>
      <ul class="space-y-2">
        <li>
          <.link class={"#{@folder == nil && "font-bold"}"} href={build_url(nil, nil, [])}>All folders</.link>
          <ul class="list-disc list-inside">
            <%= for %{name: tag} <- @all_tags do %>
              <li>
                <.link class={"#{@folder == nil && tag in @tags && "font-bold"}"} href={build_url(nil, nil, [tag])}><%= tag %></.link>
                <%= if @folder == nil do %>
                    <.toggle_tag_button folder={nil} photo={nil} tags={@tags} toggled_tag={tag}><%= if(tag in @tags, do: "-", else: "+") %></.toggle_tag_button>
                  <% end %>
              </li>
            <% end %>
          </ul>
        </li>
        <%= for folder <- @all_folders do %>
          <li>
            <.link class={"#{folder.name == @folder && "font-bold"}"} href={build_url(folder.name, nil, [])}><%= folder.name %></.link>
            <ul class="list-disc list-inside">
              <%= for tag <- folder.tags do %>
                <% recommended_tag_names = Enum.map(@recommended_tags, & &1.name) %>
                <li>
                  <.link class={"#{@folder == folder.name && tag in @tags && "font-bold"}"} href={build_url(folder.name, nil, [tag])}><%= tag %></.link>
                  <%= if @folder == folder.name && tag in recommended_tag_names do %>
                    <.toggle_tag_button folder={folder.name} photo={nil} tags={@tags} toggled_tag={tag}><%= if(tag in @tags, do: "-", else: "+") %></.toggle_tag_button>
                  <% end %>
                </li>
              <% end %>
            </ul>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  attr(:photos, :list, required: true)
  attr(:folder, :string, default: nil)
  attr(:tags, :list, default: [])

  def gallery(assigns) do
    ~H"""
    <div>
      <ul class="flex flex-wrap gap-4">
        <%= for photo <- @photos do %>
          <li class="w-40 h-40">
            <.link class="h-full" href={build_url(@folder, photo, @tags)} >
              <%!-- use object-cover for cropped squares, and object-contain for shrinked full images --%>
              <img
                class="w-40 h-40 object-cover"
                src={ImageUploader.url({photo.image, photo}, :small)}
              />
            </.link>
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

  def photo(assigns) do
    ~H"""
    <.list class="pb-4">
      <:item title="Image">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)} target="_blank">
          <img src={ImageUploader.url({@photo.image, @photo}, :small)} />
        </.link>
      </:item>
      <:item title="Folder">
        <.link class={"#{@folder == @photo.folder && "font-bold"}"} href={build_url(@photo.folder, @photo, @tags)}><%= @photo.folder %></.link>
      </:item>
      <:item title="Tags">
        <ul>
          <%= for tag <- @photo.tags do %>
            <li >
              <.toggle_tag_button folder={@folder} photo={@photo} tags={@tags} toggled_tag={tag.name}><%= if(tag.name in @tags, do: "- ", else: "+ ") <> tag.name %></.toggle_tag_button>
              <.form class="inline"  action={build_cannonical_photo_url(@folder, @photo, @tags, "/tags/#{tag.name}")} method="delete">
                <button type="submit"><.icon name="hero-trash-micro" class="text-red-700 hover:text-red-900"/></button>
              </.form>
            </li>
          <% end %>
        </ul>
      </:item>
      <:item title="Add tags">
        <%= for tag <- @recommended_tags do %>
          <%= if tag not in @photo.tags do %>
            <.form for={%{"tag" => ""}} action={build_cannonical_photo_url(@folder, @photo, @tags, "/tags")} method="post">
              <input class="hidden" type="text" name="tag" value={tag.name} />
              <button class="border border-blue-600 rounded-full hover:bg-blue-100 px-1 my-1 text-blue-600 hover:text-blue-800" type="submit"><%= tag.name %></button>
            </.form>
          <% end %>
        <% end %>
        <.simple_form :let={f} for={%{"tag" => ""}} action={build_cannonical_photo_url(@folder, @photo, @tags, "/tags")} method="post">
          <.input field={f[:tag]} type="text" label="Other" />
          <:actions>
            <.button type="submit">Add tag</.button>
          </:actions>
        </.simple_form>
      </:item>
      <:item title="Download file">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)} download><%= @photo.name %></.link>
      </:item>
      <:item title="Edit">
        <.form action={build_cannonical_photo_url(@folder, @photo, @tags)} method="put">
          <.input name="photo[name]" type="text" label="Name" value={@photo.name}/>
          <.input name="photo[folder]" type="text" label="Folder" value={@photo.folder} />
          <.input name="photo[notes]" type="textarea" label="Notes" value={@photo.notes} />
          <.input name="photo[description]" type="textarea" label="Description" value={@photo.description} />
          <.button class="mt-4">Save</.button>
        </.form>
      </:item>
      <:item title="Delete">
        <.form action={build_cannonical_photo_url(@folder, @photo, @tags)} method="delete"
          onsubmit={"return confirm('Are you sure you want to permanently delete this photo?')"}
        >
          <.button class="bg-red-600 hover:bg-red-900">Delete</.button>
        </.form>
      </:item>
    </.list>
    """
  end
end

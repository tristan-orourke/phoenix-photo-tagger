defmodule PhotoTaggerWeb.PhotoHTML do
  use PhotoTaggerWeb, :html
  import PhotoTaggerWeb.PhotoController, only: [build_url: 3, build_url: 4]
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
        #{if(@toggled_tag in @tags, do: "bg-red-500 text-black hover:text-black", else: "bg-green-500 text-white hover:text-white")}
    ~H"""
      <.link class={"
        #{@toggled_tag in @tags && "font-bold"}
        rounded-full px-1"} href={@href}>
        <%= render_slot(@inner_block) %>
      </.link>
    """
  end

  attr(:all_folders, :list, required: true)
  attr(:all_tags, :list, required: true)
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
            <%= for tag <- @all_tags do %>
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
                <li>
                  <.link class={"#{@folder == folder.name && tag in @tags && "font-bold"}"} href={build_url(folder.name, nil, [tag])}><%= tag %></.link>
                  <%= if @folder == folder.name do %>
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
      <:item title="Name"><%= @photo.name %></:item>
      <:item title="Folder">
        <.link class={"#{@folder == @photo.folder && "font-bold"}"} href={build_url(@photo.folder, @photo, @tags)}><%= @photo.folder %></.link>
      </:item>
      <:item title="Tags">
        <ul>
          <%= for tag <- @photo.tags do %>
            <li >
              <.toggle_tag_button folder={@folder} photo={@photo} tags={@tags} toggled_tag={tag.name}><%= if(tag.name in @tags, do: "- ", else: "+ ") <> tag.name %></.toggle_tag_button>
              <.form class="inline"  action={build_url(@folder, @photo, @tags, "/tags/#{tag.name}")} method="delete">
                <button type="submit"><.icon name="hero-trash-micro" class="text-red-700 hover:text-red-900"/></button>
              </.form>
            </li>
          <% end %>
        </ul>
      </:item>
      <:item title="Add tags">
        <%= for tag <- @recommended_tags do %>
          <%= if tag not in @photo.tags do %>
            <.form for={%{"tag" => ""}} action={build_url(@folder, @photo, @tags, "/tags")} method="post">
              <input class="hidden" type="text" name="tag" value={tag.name} />
              <button class="border border-blue-600 rounded-full hover:bg-blue-100 px-1 my-1 text-blue-600 hover:text-blue-800" type="submit"><%= tag.name %></button>
            </.form>
          <% end %>
        <% end %>
        <.simple_form :let={f} for={%{"tag" => ""}} action={build_url(@folder, @photo, @tags, "/tags")} method="post">
          <.input field={f[:tag]} type="text" label="Other" />
          <:actions>
            <.button type="submit">Add tag</.button>
          </:actions>
        </.simple_form>
      </:item>
      <:item title="Image">
        <img src={ImageUploader.url({@photo.image, @photo}, :small)} />
      </:item>
      <:item title="Original file">
        <.link href={ImageUploader.url({@photo.image, @photo}, :original)}><%= @photo.name %></.link>
      </:item>
    </.list>
    """
  end
end

defmodule PhotoTaggerWeb.PhotoHTML do
  use PhotoTaggerWeb, :html
  import PhotoTaggerWeb.PhotoController, only: [build_url: 3]

  embed_templates("photo_html/*")

  attr(:folder, :string, required: true)
  attr(:photo, :map, required: true)
  attr(:tags, :list, required: true)
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
      <ul>
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
                src={PhotoTagger.Uploaders.ImageUploader.url({photo.image, photo}, :small)}
              />
            </.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  attr(:photo, :map, required: true)
  attr(:tags, :list, default: [])

  def photo(assigns) do
    ~H"""
    <.list>
      <:item title="Name"><%= @photo.name %></:item>
      <:item title="Folder"><%= @photo.folder %></:item>
      <:item title="Tags">
        <ul>
          <%= for tag <- @photo.tags do %>
            <li>
              <.toggle_tag_button folder={@photo.folder} photo={@photo} tags={@tags} toggled_tag={tag.name}><%= if(tag.name in @tags, do: "- ", else: "+ ") <> tag.name %></.toggle_tag_button>
            </li>
          <% end %>
        </ul>
      </:item>
      <:item title="Add tags">
        <.simple_form :let={f} for={%{"tag" => ""}} action={~p"/photos/#{@photo}/tags"} method="post">
          <.input field={f[:tag]} type="text" label="New tag" />
          <:actions>
            <.button>Add tag</.button>
          </:actions>
        </.simple_form>
      </:item>
      <:item title="Image">
        <img src={PhotoTagger.Uploaders.ImageUploader.url({@photo.image, @photo}, :small)} />
      </:item>
    </.list>
    """
  end
end

defmodule PhotoTaggerWeb.PhotoHTML do
  use PhotoTaggerWeb, :html

  embed_templates("photo_html/*")

  defp toggle_tag_href(folder, photo, tags \\ [], toggled_tag \\ nil) do
    uri = URI.new!("/")
    uri = if(folder, do: URI.append_path(uri, "/folders/#{folder}"), else: uri)
    uri = if(photo, do: URI.append_path(uri, "/photos/#{photo.id}"), else: uri)

    tags_list =
      cond do
        toggled_tag == nil -> tags
        toggled_tag in tags -> Enum.filter(tags, &(&1 != toggled_tag))
        true -> tags ++ [toggled_tag]
      end

    query = Plug.Conn.Query.encode(%{query_tags: tags_list})
    uri = URI.append_query(uri, query)

    URI.to_string(uri)
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
          <.link class={"#{@folder == nil && "font-bold"}"} href={toggle_tag_href(nil, nil, [])}>All folders</.link>
          <ul class="list-disc list-inside">
            <%= for tag <- @all_tags do %>
              <li>
                <.link class={"#{@folder == nil && tag in @tags && "font-bold"}"} href={toggle_tag_href(nil, nil, [], tag)}><%= tag %></.link>
                <%= if @folder == nil do %>
                    <.link href={toggle_tag_href(nil, nil, @tags, tag)}><%= if(tag in @tags, do: "-", else: "+") %></.link>
                  <% end %>
              </li>
            <% end %>
          </ul>
        </li>
        <%= for folder <- @all_folders do %>
          <li>
            <.link class={"#{folder.name == @folder && "font-bold"}"} href={toggle_tag_href(folder.name, nil, [])}><%= folder.name %></.link>
            <ul class="list-disc list-inside">
              <%= for tag <- folder.tags do %>
                <li>
                  <.link class={"#{@folder == folder.name && tag in @tags && "font-bold"}"} href={toggle_tag_href(folder.name, nil, [], tag)}><%= tag %></.link>
                  <%= if @folder == folder.name do %>
                    <.link href={toggle_tag_href(folder.name, nil, @tags, tag)}><%= if(tag in @tags, do: "-", else: "+") %></.link>
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
            <.link class="h-full" href={toggle_tag_href(@folder, photo, @tags)} >
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

  def photo(assigns) do
    ~H"""
    <.list>
      <:item title="Name"><%= @photo.name %></:item>
      <:item title="Folder"><%= @photo.folder %></:item>
      <:item title="Tags">
        <ul>
          <%= for tag <- @photo.tags do %>
            <li><%= tag.name %></li>
          <% end %>
        </ul>
      </:item>
      <:item title="Image">
        <img src={PhotoTagger.Uploaders.ImageUploader.url({@photo.image, @photo}, :small)} />
      </:item>
    </.list>
    """
  end
end

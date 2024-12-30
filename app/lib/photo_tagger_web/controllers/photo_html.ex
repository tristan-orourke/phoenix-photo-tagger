defmodule PhotoTaggerWeb.PhotoHTML do
  use PhotoTaggerWeb, :html

  embed_templates("photo_html/*")

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
          <.link href={~p"/"}>All</.link>
          <ul class="list-disc list-inside">
            <%= for tag <- @all_tags do %>
              <li>
                <.link href={~p"/photos?query_tags=#{tag}"}><%= tag %></.link>
              </li>
            <% end %>
          </ul>
        </li>
        <%= for folder <- @all_folders do %>
          <li>
            <.link href={~p"/folders/#{folder.name}"}><%= folder.name %></.link>
            <ul class="list-disc list-inside">
              <%= for tag <- folder.tags do %>
                <li>
                  <.link href={~p"/folders/#{folder.name}?query_tags=#{tag}"}><%= tag %></.link>
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

  def gallery(assigns) do
    ~H"""
    <div>
      <ul class="flex flex-wrap gap-4">
        <%= for photo <- @photos do %>
          <li class="w-40 h-40">
            <.link class="h-full" href={~p"/photos/#{photo.id}"} >
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

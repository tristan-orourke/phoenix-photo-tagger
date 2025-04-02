defmodule PhotoTaggerWeb.GalleryLive.FolderNavItem do
  use PhotoTaggerWeb, :live_component
  alias PhotoTaggerWeb.HtmlHelpers
  import PhotoTaggerWeb.Components.Accordion

  attr(:nav_tags, :list, required: true)
  attr(:recommended_tags, :list, required: true)
  attr(:nav_folder, :string, default: nil)
  attr(:is_current_folder, :boolean, default: false)
  attr(:tags, :list, default: [])

  def render(assigns) do
    recommended_tag_names = Enum.map(assigns.recommended_tags, & &1.name)

    {recommended_nav_tags, other_nav_tags} =
      Enum.split_with(assigns.nav_tags, &(&1 in recommended_tag_names))

    recommended_nav_tags =
      Enum.sort_by(recommended_nav_tags, fn tag ->
        cond do
          # show currently selected tags first
          tag in assigns.tags -> 0
          # tag in @recommended_tag_names -> 1 # then recommended tags
          # then other tags
          true -> 2
        end
      end)

    assigns =
      assigns
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
                data-selected={@is_current_folder}
                patch={build_url(@nav_folder, [], [])}
              >
              {if(@nav_folder, do: @nav_folder, else: "All folders")}
            </.link>
          </p>
        </:trigger>
        <:panel default_expanded={@is_current_folder}>
          <div class="divide-y divide-zinc-300 my-2 pl-2 list-none">
            <%= if not Enum.empty?(@recommended_nav_tags) do %>
              <ul class="md:flex md:flex-wrap my-2">
                <%= for tag <- @recommended_nav_tags do %>
                  <li class="mr-2 flex items-center">
                      <.toggle_tag_button folder={@nav_folder} tags={@tags} toggled_tag={tag}>
                        {tag}
                      </.toggle_tag_button>
                  </li>
                <% end %>
              </ul>
            <% end %>
            <%= if not Enum.empty?(@other_nav_tags) do %>
              <ul class="md:flex md:flex-wrap py-2">
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

  attr(:folder, :string, default: nil)
  attr(:selected_photos, :list, default: [])
  attr(:tags, :list, default: [])
  attr(:toggled_tag, :string, required: true)
  attr(:class, :string, default: "")
  slot(:inner_block)

  # TODO: duplicated in main. Move to utility module
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

    assigns = assign(assigns, :selected, assigns.toggled_tag in assigns.tags)

    ~H"""
    <.toggle_link
      selected={@selected}
      href={@href}
      class={@class}
    >
      {render_slot(@inner_block)}
    </.toggle_link>
    """
  end

  # TODO: duplicated in main. Move to utility module
  def folder_accordion_id(folder) do
    if folder do
      HtmlHelpers.escape_html_id("accordion-#{folder}")
    else
      "accordion-all-folders"
    end
  end

  # TODO: duplicated in main. Move to utility module
  def build_url(folder, selected_photos, tags) do
    {photo_id, selected_photo_ids} =
      case selected_photos do
        [photo] -> {photo.id, []}
        photos -> {nil, Enum.map(photos, & &1.id)}
      end

    uri =
      case {folder, photo_id} do
        {nil, nil} -> URI.encode("/photos")
        {folder, nil} -> URI.encode("/folders/#{folder}")
        {nil, photo_id} -> URI.encode("/photos/#{photo_id}")
        {folder, photo_id} -> URI.encode("/folders/#{folder}/photos/#{photo_id}")
      end
      |> URI.new!()

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
end

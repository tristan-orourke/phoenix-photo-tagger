defmodule PhotoTaggerWeb.GalleryLive.GalleryPhoto do
  use PhotoTaggerWeb, :live_component
  alias PhotoTagger.Uploaders.ImageUploader

  attr(:photo_id, :string, required: true)
  attr(:photo_group, :string, default: nil)
  attr(:photo_name, :string, required: true)
  attr(:photo_image, :string, required: true)
  attr(:photo_folder, :string, required: true)
  attr(:is_selected, :boolean, default: false)
  attr(:is_group_collapsed, :boolean, default: false)
  attr(:is_admin, :boolean, default: false)
  attr(:group_left, :boolean, default: false)
  attr(:group_right, :boolean, default: false)
  attr(:is_group_topper, :boolean, default: false)
  attr(:photo_is_public, :boolean, default: nil)
  attr(:show_visibility_outline, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <li class={"relative py-1 lg:py-1.5 lg:my-0.5
      #{if(@group_left, do: "pl-1 lg:pl-2", else: "pl-1.5 lg:ml-0.5")}
      #{if(@group_right, do: "pr-1 lg:pr-2", else: "pr-1.5 lg:mr-0.5")}
      #{if(@photo_group != nil and !@is_group_collapsed, do: "bg-blue-200", else: "")}"}

    >
      <div class="aspect-square w-full h-full">
        <button :if={@is_group_topper} class="z-50 absolute w-8 h-8 right-0 top-0"
          phx-click="toggle_collapse_single_group"
          phx-value-photo_group={@photo_group}
        >
          <p>{if(@is_group_collapsed, do: "[+]", else: "[-]")}</p>
        </button>
        <button
          id={"gallery-photo-button-#{@photo_id}"}
          class={"h-full w-full relative block
            square-image
            data-[selected]:outline
            outline-4 outline-offset-2 data-[selected]:outline-blue-400
            phx-click-loading:outline phx-click-loading:outline-blue-200
            #{@visibility_outline_class}"}
          data-selected={@is_selected}
          phx-click={if(@is_group_collapsed and @photo_group != nil and @is_admin, do: "select_gallery_group", else: "select_gallery_photo")}
          phx-value-photo_id={@photo_id}
          phx-value-photo_group={@photo_group}
        >
          <%!-- use object-cover for cropped squares, and object-contain for shrinked full images --%>
          <img
            class="w-full h-full aspect-square object-cover"
            alt={@photo_name}
            src={@photo_image_url}
          />
          <%= if @is_group_collapsed and @photo_group do %>
            <div class={"w-full h-full -z-10 absolute left-1 bottom-1 bg-gray-500"} />
            <div class={"w-full h-full -z-20 absolute left-2 bottom-2 bg-gray-400"} />
          <% end %>
        </button>
      </div>
    </li>
    """
  end

  def update(assigns, socket) do
    # Compute visibility outline classes - green for public, red for private
    # Only show when visibility outlines are enabled and photo is not selected
    visibility_outline_class =
      cond do
        assigns.is_selected -> ""
        assigns.show_visibility_outline and assigns.photo_is_public == true ->
          "outline outline-green-500"
        assigns.show_visibility_outline and assigns.photo_is_public == false ->
          "outline outline-red-500"
        true -> ""
      end

    {:ok,
     assign(
       socket,
       :photo_image_url,
       ImageUploader.url({assigns.photo_image, %{folder: assigns.photo_folder}}, :thumb)
     )
     |> assign(:visibility_outline_class, visibility_outline_class)
     |> assign(Map.drop(assigns, [:photo_image, :photo_folder]))}
  end
end

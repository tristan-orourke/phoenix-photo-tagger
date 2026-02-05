defmodule PhotoTaggerWeb.FolderHTML do
  use PhotoTaggerWeb, :html

  attr(:folders, :list, required: true)

  def index(assigns) do
    ~H"""
    <div class="flex h-screen items-center justify-center">
      <div class="pb-60">
        <div class="pb-20 pt-12 px-12 shadow-xl">
          <h1 class="text-4xl font-semibold text-zinc-800 p-8">
            Available Galleries
          </h1>
          <nav>
            <ul class="text-center align-middle h-full text-2xl space-y-4">
              <%= for %{name: folder} <- @folders do %>
                <li>
                  <.link href={~p"/folders/#{folder}"} class="text-blue-500 hover:underline">
                    <%= folder %>
                  </.link>
                </li>
              <% end %>
            </ul>
          </nav>
        </div>
      </div>
    </div>
    """
  end

  attr(:folders, :list, required: true)

  def edit_folders(assigns) do
    ~H"""
    <h2>
      Edit Folders
    </h2>

    <ul>
      <%= for %{name: folder, visibility_type: visibility_type} <- @folders do %>
        <li class="mb-8">
          <p class="font-bold">{folder}</p>
          <div class="ml-4">
            <div>
              <.form for={%{}} action={~p"/admin/folders/#{folder}"} method="put">
                <div class="flex items-center space-x-4">
                  <.label for={"folder_name_#{folder}"}>Name</.label>
                  <input
                    type="text"
                    name="name"
                    id={"folder_name_#{folder}"}
                    placeholder={folder}
                    value={folder}
                    class="block max-w-64 rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
                  />
                </div>
                <div class="flex items-center space-x-4 mt-4">
                  <.label>Visibility</.label>
                  <div class="flex space-x-4">
                    <label class="flex items-center">
                      <input
                        type="radio"
                        name="visibility_type"
                        value="private"
                        checked={visibility_type == :private}
                        class="rounded focus:ring-0"
                      />
                      <span class="ml-1">Private</span>
                    </label>
                    <label class="flex items-center">
                      <input
                        type="radio"
                        name="visibility_type"
                        value="public"
                        checked={visibility_type == :public}
                        class="rounded focus:ring-0"
                      />
                      <span class="ml-1">Public</span>
                    </label>
                    <label class="flex items-center">
                      <input
                        type="radio"
                        name="visibility_type"
                        value="unlisted"
                        checked={visibility_type == :unlisted}
                        class="rounded focus:ring-0"
                      />
                      <span class="ml-1">Unlisted</span>
                    </label>
                  </div>
                </div>
                <.button class="mt-4" type="submit">Update folder</.button>
              </.form>
            </div>
            <div class="mt-8">
              <.form
                for={%{}}
                action={~p"/admin/folders/#{folder}"}
                method="delete"
                onsubmit={"return confirm('Are you sure you want to delete the folder named \"#{folder}\"? This will permanently delete all photos in the folder.')"}
              >
                <.button type="submit" class="bg-red-600 text-white">{"Delete #{folder}"}</.button>
              </.form>
            </div>
          </div>
        </li>
      <% end %>
    </ul>

    <h2>Create Folder</h2>
    <.form for={%{}} action={~p"/admin/folders"} method="post">
      <div class="flex items-center space-x-4">
        <.label for={"new_folder_name"}>Name</.label>
        <input
          type="text"
          name="name"
          id={"new_folder_name"}
          class="block max-w-64 rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
        />
      </div>
      <div class="flex items-center space-x-4 mt-4">
        <.label>Visibility</.label>
        <div class="flex space-x-4">
          <label class="flex items-center">
            <input
              type="radio"
              name="visibility_type"
              value="private"
              checked={true}
              class="rounded focus:ring-0"
            />
            <span class="ml-1">Private</span>
          </label>
          <label class="flex items-center">
            <input
              type="radio"
              name="visibility_type"
              value="public"
              class="rounded focus:ring-0"
            />
            <span class="ml-1">Public</span>
          </label>
          <label class="flex items-center">
            <input
              type="radio"
              name="visibility_type"
              value="unlisted"
              class="rounded focus:ring-0"
            />
            <span class="ml-1">Unlisted</span>
          </label>
        </div>
      </div>
      <.button type="submit">Create folder</.button>
    </.form>
    <.back navigate={~p"/admin/photos"}>Back to photos</.back>
    """
  end
end

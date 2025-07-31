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
    <.header>
      Edit Folders
    </.header>

    <ul>
      <%= for %{name: folder} <- @folders do %>
        <li class="mb-8">
          <p class="font-bold">{folder}</p>
          <div class="ml-4">
            <div>
              <.form for={%{}} action={~p"/admin/folders/#{folder}/rename"} method="post">
                <div class="flex items-center space-x-4">
                  <.label for={"folder_#{folder}"}>Name</.label>
                  <input
                    type="text"
                    name="new_name"
                    id={"folder_#{folder}"}
                    placeholder={folder}
                    class="block max-w-64 rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
                  />
                  <.button type="submit">Rename folder</.button>
                </div>
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

    <.back navigate={~p"/admin/photos"}>Back to photos</.back>
    """
  end
end

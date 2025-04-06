defmodule PhotoTaggerWeb.FolderHTML do
  use PhotoTaggerWeb, :html

  attr(:folders, :list, required: true)

  def edit_folders(assigns) do
    ~H"""
    <.header>
      Edit Folders
    </.header>

    <ul>
      <%= for folder <- @folders do %>
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

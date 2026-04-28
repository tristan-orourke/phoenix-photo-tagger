defmodule Mix.Tasks.ReorderPhotos do
  @moduledoc """
  Reassigns manual_order for all photos based on upload time.

  Oldest photos get the lowest order numbers. Photos with identical
  upload times are sorted alphabetically by name.

  ## Usage

      mix reorder_photos
  """

  use Mix.Task

  @shortdoc "Reorder all photos by upload time (oldest first)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    sql = """
    UPDATE photos SET manual_order = sub.new_order
    FROM (
      SELECT id, ROW_NUMBER() OVER (ORDER BY inserted_at ASC, name ASC) AS new_order
      FROM photos
    ) sub
    WHERE photos.id = sub.id
    """

    case Ecto.Adapters.SQL.query(PhotoTagger.Repo, sql) do
      {:ok, %{num_rows: count}} ->
        Mix.shell().info("Updated manual_order for #{count} photos.")

      {:error, reason} ->
        Mix.shell().error("Failed to reorder photos: #{inspect(reason)}")
    end
  end
end

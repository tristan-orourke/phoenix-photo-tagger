defmodule PhotoTagger.GalleryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PhotoTagger.Gallery` context.
  """

  @doc """
  Generate a unique photo name.
  """
  def unique_photo_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a photo.
  """
  def photo_fixture(attrs \\ %{}) do
    {:ok, photo} =
      attrs
      |> Enum.into(%{
        name: unique_photo_name()
      })
      |> PhotoTagger.Gallery.create_photo()

    photo
  end
end

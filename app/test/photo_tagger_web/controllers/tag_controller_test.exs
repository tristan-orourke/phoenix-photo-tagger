defmodule PhotoTaggerWeb.TagControllerTest do
	@moduledoc """
	Tests for the TagController handling tag CRUD operations.
	"""

	use PhotoTaggerWeb.ConnCase, async: true

	alias PhotoTagger.Gallery

	import PhotoTagger.GalleryFixtures

	describe "GET /admin/edit-tags" do
		test "renders tag list", %{conn: conn} do
			tag = tag_fixture(%{name: "test_tag"})

			conn = get(conn, ~p"/admin/edit-tags")

			assert html_response(conn, 200) =~ "Edit Tags"
			assert html_response(conn, 200) =~ tag.name
		end
	end

	describe "PUT /admin/tags/:tag" do
		test "updates tag name", %{conn: conn} do
			tag = tag_fixture(%{name: "old_tag_name"})
			new_name = "new_tag_name_#{System.unique_integer([:positive])}"

			update_params = %{
				"tag" => tag.name,
				"tag_updates" => %{"name" => new_name}
			}

			conn = put(conn, ~p"/admin/tags/#{tag.name}", update_params)

			assert redirected_to(conn) == ~p"/admin/edit-tags"
			assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag updated successfully"

			# Verify tag was renamed
			renamed_tag = Gallery.get_tag_by_name!(new_name)
			assert renamed_tag.name == new_name

			# Verify old name no longer exists
			assert_raise Ecto.NoResultsError, fn ->
				Gallery.get_tag_by_name!(tag.name)
			end
		end
	end

	describe "DELETE /admin/tags/:tag" do
		test "deletes tag", %{conn: conn} do
			tag = tag_fixture(%{name: "delete_me"})

			conn = delete(conn, ~p"/admin/tags/#{tag.name}")

			assert redirected_to(conn) == ~p"/admin/edit-tags"
			assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag deleted successfully"

			# Verify tag was deleted
			assert_raise Ecto.NoResultsError, fn ->
				Gallery.get_tag_by_name!(tag.name)
			end
		end
	end
end

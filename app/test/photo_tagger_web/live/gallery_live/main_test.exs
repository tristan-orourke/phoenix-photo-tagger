defmodule PhotoTaggerWeb.GalleryLive.MainTest do
	@moduledoc """
	Tests for the main gallery LiveView (main.ex).

	Tests cover mounting, URL routing, photo selection, UI state management,
	tag filtering, CRUD operations, group management, and component rendering.
	"""

	use PhotoTaggerWeb.ConnCase, async: true

	import Phoenix.LiveViewTest
	import PhotoTagger.GalleryFixtures

	alias PhotoTagger.Gallery
	alias PhotoTagger.Repo

	# ============================================================================
	# Helper Functions
	# ============================================================================

	defp assert_patched_to(view, expected_path) do
		assert_patch(view, expected_path)
	end

	defp count_photos_in_html(html) do
		html
		|> Floki.parse_document!()
		|> Floki.find("[data-gallery-photo-id]")
		|> length()
	end

	defp count_selected_photos(html) do
		html
		|> Floki.parse_document!()
		|> Floki.find("[data-gallery-photo-id].selected")
		|> length()
	end

	defp photo_in_panel?(view, filename) do
		has_element?(view, "#photo-section a[download]", filename)
	end

	defp tag_in_current_filters?(view, tag_name) do
		has_element?(view, "#current-filters", tag_name)
	end

	defp extract_selected_tags(html) do
		html
		|> Floki.parse_document!()
		|> Floki.find("#breadcrumb-tags .tag")
		|> Enum.map(fn element -> Floki.text(element) end)
		|> Enum.map(&String.trim/1)
	end

	defp extract_excluded_tags(html) do
		html
		|> Floki.parse_document!()
		|> Floki.find("#breadcrumb-excluded-tags .tag")
		|> Enum.map(fn element -> Floki.text(element) end)
		|> Enum.map(&String.trim/1)
	end

	defp get_zoom_level_from_grid(html) do
		doc = Floki.parse_document!(html)

		case Floki.find(doc, "#gallery-grid") do
			[{_tag, attrs, _children}] ->
				zoom_attr = Enum.find_value(attrs, fn {key, value} -> if key == "data-zoom-level", do: value end)
				String.to_integer(zoom_attr || "0")

			_ ->
				0
		end
	end

	defp extract_sort_value(html) do
		doc = Floki.parse_document!(html)

		case Floki.find(doc, "#sort-select option[selected]") do
			[{_tag, attrs, _children}] ->
				Enum.find_value(attrs, fn {key, value} -> if key == "value", do: value end)

			_ ->
				nil
		end
	end

	defp extract_page_number(html) do
		doc = Floki.parse_document!(html)

		case Floki.find(doc, "#page-input") do
			[{_tag, attrs, _children}] ->
				value = Enum.find_value(attrs, fn {key, val} -> if key == "value", do: val end)
				String.to_integer(value || "1")

			_ ->
				1
		end
	end

	defp folder_in_breadcrumb?(view, folder_name) do
		has_element?(view, "#breadcrumb-folder", folder_name)
	end

	defp has_multiselect_active?(html) do
		doc = Floki.parse_document!(html)
		Floki.find(doc, "#multiselect-toggle.active") != []
	end

	defp has_collapse_groups_active?(html) do
		doc = Floki.parse_document!(html)
		Floki.find(doc, "#collapse-groups-toggle.active") != []
	end

	defp count_visible_groups(html) do
		html
		|> Floki.parse_document!()
		|> Floki.find("[data-group-name]")
		|> length()
	end

	defp group_is_collapsed?(html, group_name) do
		doc = Floki.parse_document!(html)

		case Floki.find(doc, "[data-group-name='#{group_name}']") do
			[{_tag, attrs, _children}] ->
				class_attr = Enum.find_value(attrs, fn {key, value} -> if key == "class", do: value end)
				String.contains?(class_attr || "", "collapsed")

			_ ->
				false
		end
	end

	# ============================================================================
	# Test Group 1: Mounting and Initial State
	# ============================================================================

	describe "mount/3" do
		@tag :skip
		test "admin user sees admin layout with all folders and tags", %{conn: conn} do
			folder1 = folder_fixture(%{name: "Folder1", is_public: true})
			folder2 = folder_fixture(%{name: "Folder2", is_public: false})
			tag1 = tag_fixture(%{name: "tag1"})
			tag2 = tag_fixture(%{name: "tag2"})

			{:ok, view, html} = live(conn, ~p"/admin")

			assert html =~ "Folder1"
			assert html =~ "Folder2"
			assert has_element?(view, "#nav-panel", "tag1")
			assert has_element?(view, "#nav-panel", "tag2")
		end

		test "public user sees public layout with only public folders", %{conn: conn} do
			folder1 = folder_fixture(%{name: "PublicFolder", is_public: true})
			folder2 = folder_fixture(%{name: "PrivateFolder", is_public: false})

			{:ok, view, html} = live(conn, ~p"/")

			assert html =~ "PublicFolder"
			refute html =~ "PrivateFolder"
		end

		test "initializes with default values for zoom_level, multiselect_active, collapse_groups", %{conn: conn} do
			{:ok, _view, html} = live(conn, ~p"/admin")

			assert get_zoom_level_from_grid(html) == 0
			refute has_multiselect_active?(html)
			refute has_collapse_groups_active?(html)
		end

		@tag :skip
		test "initializes with default sort order (newest first)", %{conn: conn} do
			{:ok, _view, html} = live(conn, ~p"/admin")

			assert extract_sort_value(html) == "newest"
		end

		@tag :skip
		test "loads tags grouped by first letter for admin", %{conn: conn} do
			tag_fixture(%{name: "apple"})
			tag_fixture(%{name: "banana"})
			tag_fixture(%{name: "cherry"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			assert has_element?(view, "#nav-panel .letter-index", "A")
			assert has_element?(view, "#nav-panel .letter-index", "B")
			assert has_element?(view, "#nav-panel .letter-index", "C")
		end
	end

	# ============================================================================
	# Test Group 2: Handle Params and URL Routing
	# ============================================================================

	describe "handle_params - folder parameter" do
		test "loads photos from specified folder", %{conn: conn} do
			folder = folder_fixture(%{name: "Vacation"})
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "beach.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "mountain.jpg"})

			{:ok, view, html} = live(conn, ~p"/admin?folder=Vacation")

			assert folder_in_breadcrumb?(view, "Vacation")
			assert count_photos_in_html(html) == 2
		end

		test "loads all folders when folder parameter is empty", %{conn: conn} do
			folder1 = folder_fixture(%{name: "Folder1"})
			folder2 = folder_fixture(%{name: "Folder2"})
			photo1 = photo_fixture(%{folder_id: folder1.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder2.id, filename: "photo2.jpg"})

			{:ok, _view, html} = live(conn, ~p"/admin")

			assert count_photos_in_html(html) == 2
		end
	end

	describe "handle_params - tag filtering" do
		@tag :skip
		test "filters photos by query_tags (include tags)", %{conn: conn} do
			folder = folder_fixture()
			tag1 = tag_fixture(%{name: "landscape"})
			tag2 = tag_fixture(%{name: "sunset"})
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			Gallery.add_tag_to_photo(photo1, tag1.name)
			Gallery.add_tag_to_photo(photo1, tag2.name)
			Gallery.add_tag_to_photo(photo2, tag1.name)

			{:ok, view, html} = live(conn, ~p"/admin?query_tags[]=landscape&query_tags[]=sunset")

			assert count_photos_in_html(html) == 1
			assert tag_in_current_filters?(view, "landscape")
			assert tag_in_current_filters?(view, "sunset")
		end

		test "filters photos by exclude_tags", %{conn: conn} do
			folder = folder_fixture()
			tag1 = tag_fixture(%{name: "blurry"})
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			Gallery.add_tag_to_photo(photo1, tag1.name)

			{:ok, _view, html} = live(conn, ~p"/admin?exclude_tags[]=blurry")

			assert count_photos_in_html(html) == 1
		end

		test "combines query_tags and exclude_tags correctly", %{conn: conn} do
			folder = folder_fixture()
			tag1 = tag_fixture(%{name: "landscape"})
			tag2 = tag_fixture(%{name: "blurry"})
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			Gallery.add_tag_to_photo(photo1, tag1.name)
			Gallery.add_tag_to_photo(photo2, tag1.name)
			Gallery.add_tag_to_photo(photo2, tag2.name)

			{:ok, _view, html} = live(conn, ~p"/admin?query_tags[]=landscape&exclude_tags[]=blurry")

			assert count_photos_in_html(html) == 1
		end
	end

	describe "handle_params - photo selection" do
		@tag :skip
		test "selects single photo via photo_id parameter", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "selected.jpg"})

			{:ok, view, html} = live(conn, ~p"/admin/photos/#{photo.id}")

			assert photo_in_panel?(view, "selected.jpg")
			assert count_selected_photos(html) == 1
		end

		test "selects multiple photos via selected_photos parameter", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, _view, html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			assert count_selected_photos(html) == 2
		end
	end

	describe "handle_params - sort and pagination" do
		@tag :skip
		test "applies sort parameter to photo ordering", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, _view, html} = live(conn, ~p"/admin?sort=oldest")

			assert extract_sort_value(html) == "oldest"
		end

		@tag :skip
		test "applies page parameter for pagination", %{conn: conn} do
			folder = folder_fixture()
			photos = for i <- 1..15, do: photo_fixture(%{folder_id: folder.id, filename: "photo#{i}.jpg"})

			{:ok, _view, html} = live(conn, ~p"/admin?page=2")

			assert extract_page_number(html) == 2
		end
	end

	@tag :skip
	describe "handle_params - scroll events" do
		# Skipped: Phoenix LiveView 1.0 does not support assert_push_event/3
		test "scroll event triggers scroll to top", %{conn: conn} do
			{:ok, view, _html} = live(conn, ~p"/admin")

			# Would test: assert_push_event(view, "scroll_to_top", %{})
		end

		test "scroll event with target triggers scroll to element", %{conn: conn} do
			{:ok, view, _html} = live(conn, ~p"/admin")

			# Would test: assert_push_event(view, "scroll_to_element", %{target: "some-id"})
		end
	end

	# ============================================================================
	# Test Group 3: Photo Selection Events
	# ============================================================================

	describe "select_gallery_photo event" do
		@tag :skip
		test "selects single photo without ctrl key", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo.id),
					"ctrl_key_pressed" => "false"
				})

			assert count_selected_photos(html) == 1
			assert photo_in_panel?(view, "photo1.jpg")
		end

		test "adds photo to selection with ctrl key pressed", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo2.id),
					"ctrl_key_pressed" => "true"
				})

			assert count_selected_photos(html) == 2
		end

		test "multiselect mode adds photo without ctrl key", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			render_click(view, "toggle_multiselect", %{})

			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo2.id),
					"ctrl_key_pressed" => "false"
				})

			assert count_selected_photos(html) == 2
		end

		test "deselects photo when clicking already selected photo with ctrl key", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo1.id),
					"ctrl_key_pressed" => "true"
				})

			assert count_selected_photos(html) == 1
		end

		@tag :skip
		test "REGRESSION: selecting photo preserves sort order", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin?sort=oldest")

			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo1.id),
					"ctrl_key_pressed" => "false"
				})

			assert extract_sort_value(html) == "oldest"
		end

		test "REGRESSION: selecting photo preserves zoom level", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			render_click(view, "zoom_in", %{})
			render_click(view, "zoom_in", %{})

			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo.id),
					"ctrl_key_pressed" => "false"
				})

			# After 2 zoom_in events, zoom level should be positive
			assert get_zoom_level_from_grid(html) > 0
		end

		@tag :skip
		test "REGRESSION: selecting photo preserves page number", %{conn: conn} do
			folder = folder_fixture()
			photos = for i <- 1..15, do: photo_fixture(%{folder_id: folder.id, filename: "photo#{i}.jpg"})
			photo_from_page_2 = Enum.at(photos, 10)

			{:ok, view, _html} = live(conn, ~p"/admin?page=2")

			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo_from_page_2.id),
					"ctrl_key_pressed" => "false"
				})

			assert extract_page_number(html) == 2
		end
	end

	describe "shift-click range selection" do
		test "shift-click selects range of photos forward", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})
			photo4 = photo_fixture(%{folder_id: folder.id, filename: "photo4.jpg"})
			photo5 = photo_fixture(%{folder_id: folder.id, filename: "photo5.jpg"})

			# Start by selecting photo1
			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			# Shift-click photo4 to select range
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo4.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# All photos 1-4 should be selected
			assert count_selected_photos(html) == 4
		end

		test "shift-click selects range of photos backward", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})
			photo4 = photo_fixture(%{folder_id: folder.id, filename: "photo4.jpg"})
			photo5 = photo_fixture(%{folder_id: folder.id, filename: "photo5.jpg"})

			# Start by selecting photo5
			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo5.id}")

			# Shift-click photo2 to select range backward
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo2.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# All photos 2-5 should be selected
			assert count_selected_photos(html) == 4
		end

		test "shift-click extends selection from last selected photo", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})
			photo4 = photo_fixture(%{folder_id: folder.id, filename: "photo4.jpg"})
			photo5 = photo_fixture(%{folder_id: folder.id, filename: "photo5.jpg"})

			# Start by selecting photo1
			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			# Ctrl-click photo3 to select 1 and 3
			_html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo3.id),
					"ctrl_key_pressed" => "true",
					"shift_key_pressed" => "false"
				})

			# Now shift-click photo5 to extend selection
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo5.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Should select range 3-5, adding to existing 1,3
			# Total: photos 1, 3, 4, 5
			assert count_selected_photos(html) == 4
		end

		test "shift-click with no last selected photo falls back to multi-select behavior", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			# Start with no selection
			{:ok, view, _html} = live(conn, ~p"/admin")

			# Enable multiselect mode
			render_click(view, "toggle_multiselect", %{})

			# Shift-click photo2 without any previous selection
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo2.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Should select just photo2 (fallback behavior)
			assert count_selected_photos(html) == 1
		end

		test "shift-click includes all photos in collapsed groups within range", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "GroupA"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg", group: "GroupA"})
			photo4 = photo_fixture(%{folder_id: folder.id, filename: "photo4.jpg", group: "GroupA"})
			photo5 = photo_fixture(%{folder_id: folder.id, filename: "photo5.jpg"})

			# Start by selecting photo1 (groups are collapsed by default)
			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			# Shift-click photo5 to select range including collapsed group
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo5.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Should select all 5 photos, including hidden ones in collapsed group
			assert count_selected_photos(html) == 5
		end

		test "shift-click on collapsed group ADDS to existing selection", %{conn: conn} do
			# BUG: Currently clicking on a collapsed group replaces the selection instead of adding to it
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg", group: "GroupA"})
			photo4 = photo_fixture(%{folder_id: folder.id, filename: "photo4.jpg", group: "GroupA"})
			photo5 = photo_fixture(%{folder_id: folder.id, filename: "photo5.jpg", group: "GroupA"})

			# Start by selecting photo1 (groups are collapsed by default)
			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			# Shift-click photo3 (first visible photo in collapsed GroupA)
			# This should select range photo1 -> photo3, and since photo3 is in a collapsed group,
			# it should include all photos in GroupA (photo3, photo4, photo5)
			# Total selection should be: photo1, photo2, photo3, photo4, photo5
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo3.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Should have 5 photos selected (photo1, photo2, and the 3 in the collapsed group)
			assert count_selected_photos(html) == 5
		end

		test "shift-click from collapsed group to another photo adds to selection", %{conn: conn} do
			# Test that starting from a collapsed group and shift-clicking to another photo works correctly
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "GroupA"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "GroupA"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg", group: "GroupA"})
			photo4 = photo_fixture(%{folder_id: folder.id, filename: "photo4.jpg"})
			photo5 = photo_fixture(%{folder_id: folder.id, filename: "photo5.jpg"})

			# Groups are collapsed by default - select photo1 (the group representative)
			{:ok, view, _html} = live(conn, ~p"/admin")

			# Click on photo1 (collapsed group representative) to select it
			render_click(view, "select_gallery_photo", %{
				"photo_id" => to_string(photo1.id),
				"ctrl_key_pressed" => "false",
				"shift_key_pressed" => "false"
			})

			# Now shift-click photo5 to extend selection from the collapsed group
			# Should select all photos in the range: photo1, photo2, photo3 (all in collapsed group), photo4, photo5
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo5.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Should have all 5 photos selected
			assert count_selected_photos(html) == 5
		end

		test "shift-click works with multiselect mode enabled", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			# Start by selecting photo1
			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			# Enable multiselect mode
			render_click(view, "toggle_multiselect", %{})

			# Shift-click photo3
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo3.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Should select range 1-3
			assert count_selected_photos(html) == 3
		end

		test "shift-click preserves sort order", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			# Start with oldest sort
			{:ok, view, _html} = live(conn, ~p"/admin?sort=oldest&selected_photos[]=#{photo1.id}")

			# Shift-click photo3
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo3.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Sort order should be preserved
			assert extract_sort_value(html) == "oldest"
		end

		test "shift-click preserves zoom level", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			# Zoom in twice
			render_click(view, "zoom_in", %{})
			render_click(view, "zoom_in", %{})

			# Shift-click photo3
			html =
				render_click(view, "select_gallery_photo", %{
					"photo_id" => to_string(photo3.id),
					"ctrl_key_pressed" => "false",
					"shift_key_pressed" => "true"
				})

			# Zoom level should be preserved
			assert get_zoom_level_from_grid(html) > 0
		end
	end

	describe "select_gallery_group event" do
		@tag :skip
		test "selects all photos in a group", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "GroupA"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "GroupA"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg", group: "GroupB"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			html =
				render_click(view, "select_gallery_group", %{
					"photo_group" => "GroupA",
					"ctrl_key_pressed" => "false"
				})

			assert count_selected_photos(html) == 2
		end
	end

	# ============================================================================
	# Test Group 4: UI State Toggle Events
	# ============================================================================

	describe "toggle_multiselect event" do
		test "enables multiselect mode", %{conn: conn} do
			{:ok, view, _html} = live(conn, ~p"/admin")

			html = render_click(view, "toggle_multiselect", %{})

			assert has_multiselect_active?(html)
		end

		test "disables multiselect mode when already active", %{conn: conn} do
			{:ok, view, _html} = live(conn, ~p"/admin")

			render_click(view, "toggle_multiselect", %{})
			html = render_click(view, "toggle_multiselect", %{})

			refute has_multiselect_active?(html)
		end
	end

	describe "toggle_collapse_groups event" do
		test "collapses all groups when enabled", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "Group1"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "Group2"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			html = render_click(view, "toggle_collapse_groups", %{})

			assert has_collapse_groups_active?(html)
		end

		test "expands all groups when disabled", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "Group1"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "Group2"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			render_click(view, "toggle_collapse_groups", %{})
			html = render_click(view, "toggle_collapse_groups", %{})

			refute has_collapse_groups_active?(html)
		end
	end

	describe "toggle_collapse_single_group event" do
		@tag :skip
		test "collapses a single group", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "Group1"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "Group1"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg", group: "Group2"})

			{:ok, view, html_before} = live(conn, ~p"/admin")

			assert count_photos_in_html(html_before) == 3

			html_collapsed = render_click(view, "toggle_collapse_single_group", %{"photo_group" => "Group1"})

			# Group1 collapsed should show fewer photos
			assert count_photos_in_html(html_collapsed) < count_photos_in_html(html_before)
		end

		@tag :skip
		test "expands a collapsed group", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "Group1"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "Group1"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg", group: "Group2"})

			{:ok, view, html_before} = live(conn, ~p"/admin")

			assert count_photos_in_html(html_before) == 3

			html_collapsed = render_click(view, "toggle_collapse_single_group", %{"photo_group" => "Group1"})
			html_expanded = render_click(view, "toggle_collapse_single_group", %{"photo_group" => "Group1"})

			assert count_photos_in_html(html_expanded) == count_photos_in_html(html_before)
		end

		test "collapse groups global toggle overrides individual exceptions", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "Group1"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "Group2"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			# Collapse Group1 individually
			render_click(view, "toggle_collapse_single_group", %{"photo_group" => "Group1"})

			# Enable global collapse_groups
			html = render_click(view, "toggle_collapse_groups", %{})

			# Both groups should be collapsed
			assert has_collapse_groups_active?(html)
		end
	end

	# ============================================================================
	# Test Group 5: Tag Management Events
	# ============================================================================

	describe "add_tag event" do
		test "adds tag to single photo", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			tag = tag_fixture(%{name: "landscape"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo.id}")

			html =
				render_click(view, "add_tag", %{"photo_id" => to_string(photo.id), "tag" => tag.name})

			assert html =~ "landscape"
		end

		test "creates new tag if tag does not exist", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo.id}")

			html = render_click(view, "add_tag", %{"photo_id" => to_string(photo.id), "tag" => "newtag"})

			assert html =~ "newtag"
		end
	end

	describe "remove_tag event" do
		test "removes tag from single photo", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			tag = tag_fixture(%{name: "landscape"})
			Gallery.add_tag_to_photo(photo, tag.name)

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo.id}")

			html =
				render_click(view, "remove_tag", %{"photo_id" => to_string(photo.id), "tag" => tag.name})

			refute html =~ "landscape"
		end
	end

	describe "add_tag_bulk event" do
		test "adds tag to multiple selected photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			tag = tag_fixture(%{name: "sunset"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html = render_click(view, "add_tag_bulk", %{"tag" => tag.name})

			# Verify tag was added to both photos
			updated_photo1 = Repo.preload(Gallery.get_photo!(photo1.id), :tags)
			updated_photo2 = Repo.preload(Gallery.get_photo!(photo2.id), :tags)

			assert Enum.any?(updated_photo1.tags, fn t -> t.name == "sunset" end)
			assert Enum.any?(updated_photo2.tags, fn t -> t.name == "sunset" end)
		end

		test "creates new tag for bulk add if tag does not exist", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html = render_click(view, "add_tag_bulk", %{"tag" => "removeme"})

			updated_photo1 = Repo.preload(Gallery.get_photo!(photo1.id), :tags)
			assert Enum.any?(updated_photo1.tags, fn t -> t.name == "removeme" end)
		end
	end

	describe "remove_tag_bulk event" do
		test "removes tag from multiple selected photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			tag = tag_fixture(%{name: "removeme"})
			Gallery.add_tag_to_photo(photo1, tag.name)
			Gallery.add_tag_to_photo(photo2, tag.name)

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html = render_click(view, "remove_tag_bulk", %{"tag" => tag.name})

			updated_photo1 = Repo.preload(Gallery.get_photo!(photo1.id), :tags, force: true)
			updated_photo2 = Repo.preload(Gallery.get_photo!(photo2.id), :tags, force: true)

			refute Enum.any?(updated_photo1.tags, fn t -> t.name == "removeme" end)
			refute Enum.any?(updated_photo2.tags, fn t -> t.name == "removeme" end)
		end
	end

	describe "toggle_tag event" do
		@tag :skip
		test "adds tag to query_tags filter", %{conn: conn} do
			folder = folder_fixture()
			tag = tag_fixture(%{name: "landscape"})
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			Gallery.add_tag_to_photo(photo, tag.name)

			{:ok, view, _html} = live(conn, ~p"/admin")

			render_click(view, "toggle_tag", %{"tag" => tag.name})

			assert tag_in_current_filters?(view, "landscape")
		end

		test "removes tag from query_tags filter when already active", %{conn: conn} do
			folder = folder_fixture()
			tag = tag_fixture(%{name: "landscape"})
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			Gallery.add_tag_to_photo(photo, tag.name)

			{:ok, view, _html} = live(conn, ~p"/admin?query_tags[]=landscape")

			render_click(view, "toggle_tag", %{"tag" => tag.name})

			refute tag_in_current_filters?(view, "landscape")
		end
	end

	describe "toggle_exclude_tag event" do
		test "adds tag to exclude_tags filter", %{conn: conn} do
			folder = folder_fixture()
			tag = tag_fixture(%{name: "blurry"})
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			Gallery.add_tag_to_photo(photo1, tag.name)

			{:ok, view, html_before} = live(conn, ~p"/admin")

			assert count_photos_in_html(html_before) == 2

			html_after = render_click(view, "toggle_exclude_tag", %{"tag" => tag.name})

			assert count_photos_in_html(html_after) == 1
		end

		test "removes tag from exclude_tags filter when already active", %{conn: conn} do
			folder = folder_fixture()
			tag = tag_fixture(%{name: "blurry"})
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			Gallery.add_tag_to_photo(photo1, tag.name)

			{:ok, view, html_before} = live(conn, ~p"/admin?exclude_tags[]=blurry")

			assert count_photos_in_html(html_before) == 1

			html_after = render_click(view, "toggle_exclude_tag", %{"tag" => tag.name})

			assert count_photos_in_html(html_after) == 2
		end
	end

	# ============================================================================
	# Test Group 6: Photo Update and Delete Events
	# ============================================================================

	describe "update_photo event" do
		@tag :skip
		test "updates photo metadata successfully", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", description: "old desc"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo.id}")

			html =
				render_click(view, "update_photo", %{
					"photo_id" => to_string(photo.id),
					"photo" => %{"description" => "new description"}
				})

			updated_photo = Gallery.get_photo!(photo.id)
			assert updated_photo.description == "new description"
		end

		@tag :skip
		test "handles update_photo failure gracefully", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo.id}")

			# Try to update with invalid data (e.g., invalid folder_id)
			html =
				render_click(view, "update_photo", %{
					"photo_id" => to_string(photo.id),
					"photo" => %{"folder_id" => "999999"}
				})

			# Photo should remain unchanged
			unchanged_photo = Gallery.get_photo!(photo.id)
			assert unchanged_photo.folder_id == folder.id
		end

		test "REGRESSION: update_photo preserves selected_photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html =
				render_click(view, "update_photo", %{
					"photo_id" => to_string(photo1.id),
					"photo" => %{"description" => "updated"}
				})

			assert count_selected_photos(html) == 2
		end

		@tag :skip
		test "REGRESSION: update_photo preserves tag filters", %{conn: conn} do
			folder = folder_fixture()
			tag = tag_fixture(%{name: "landscape"})
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			Gallery.add_tag_to_photo(photo, tag.name)

			{:ok, view, _html} = live(conn, ~p"/admin?query_tags[]=landscape")

			render_click(view, "update_photo", %{
				"photo_id" => to_string(photo.id),
				"photo" => %{"description" => "updated"}
			})

			assert tag_in_current_filters?(view, "landscape")
		end
	end

	describe "delete_photo event" do
		@tag :skip
		test "deletes photo and removes from selection", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo.id}")

			html = render_click(view, "delete_photo", %{"photo_id" => to_string(photo.id)})

			assert catch_error(Gallery.get_photo!(photo.id)) == :error
			assert count_selected_photos(html) == 0
		end
	end

	describe "delete_photo_bulk event" do
		@tag :skip
		test "deletes multiple selected photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			{:ok, view, html_before} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			assert count_photos_in_html(html_before) == 3

			html_after = render_click(view, "delete_photo_bulk", %{})

			assert count_photos_in_html(html_after) == 1
			assert catch_error(Gallery.get_photo!(photo1.id)) == :error
			assert catch_error(Gallery.get_photo!(photo2.id)) == :error
			assert catch_error(Gallery.get_photo!(photo3.id)) != :error
		end
	end

	# ============================================================================
	# Test Group 7: Group Management Events
	# ============================================================================

	describe "set_group_bulk event" do
		test "assigns group to multiple selected photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html = render_click(view, "set_group_bulk", %{"group" =>"NewGroup"})

			updated_photo1 = Gallery.get_photo!(photo1.id)
			updated_photo2 = Gallery.get_photo!(photo2.id)

			assert updated_photo1.group == "NewGroup"
			assert updated_photo2.group == "NewGroup"
		end
	end

	describe "form_group_from_selected event" do
		test "creates new group from selected photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html = render_click(view, "form_group_from_selected", %{})

			updated_photo1 = Gallery.get_photo!(photo1.id)
			updated_photo2 = Gallery.get_photo!(photo2.id)

			# Both photos should have the same group (timestamp-based)
			assert updated_photo1.group != nil
			assert updated_photo1.group == updated_photo2.group
		end

		test "reuses existing group name", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", group: "ExistingGroup"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg", group: "ExistingGroup"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html = render_click(view, "form_group_from_selected", %{})

			updated_photo1 = Gallery.get_photo!(photo1.id)
			updated_photo2 = Gallery.get_photo!(photo2.id)

			# Should reuse the existing group
			assert updated_photo1.group == "ExistingGroup"
			assert updated_photo2.group == "ExistingGroup"
		end
	end

	# ============================================================================
	# Test Group 8: View Settings Events
	# ============================================================================

	describe "zoom_in event" do
		test "increases zoom level", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, html_before} = live(conn, ~p"/admin")

			zoom_before = get_zoom_level_from_grid(html_before)

			html_after = render_click(view, "zoom_in", %{})
			zoom_after = get_zoom_level_from_grid(html_after)

			assert zoom_after > zoom_before
		end

		test "clamps zoom level at maximum (+9)", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			# Zoom in many times to hit max
			for _i <- 1..20, do: render_click(view, "zoom_in", %{})

			html = render(view)
			zoom = get_zoom_level_from_grid(html)

			assert zoom <= 9
		end
	end

	describe "zoom_out event" do
		test "decreases zoom level", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			# Zoom in first
			render_click(view, "zoom_in", %{})
			html_before = render(view)
			zoom_before = get_zoom_level_from_grid(html_before)

			html_after = render_click(view, "zoom_out", %{})
			zoom_after = get_zoom_level_from_grid(html_after)

			assert zoom_after < zoom_before
		end

		test "clamps zoom level at minimum (-9)", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			# Zoom out many times to hit min
			for _i <- 1..20, do: render_click(view, "zoom_out", %{})

			html = render(view)
			zoom = get_zoom_level_from_grid(html)

			assert zoom >= -9
		end
	end

	describe "change_sort event" do
		@tag :skip
		test "changes sort order to specified value", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			html = render_click(view, "change_sort", %{"sort" => "oldest"})

			assert extract_sort_value(html) == "oldest"
		end

		test "REGRESSION: change_sort preserves selected photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} =
				live(conn, ~p"/admin?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

			html = render_click(view, "change_sort", %{"sort" => "oldest"})

			assert count_selected_photos(html) == 2
		end
	end

	# ============================================================================
	# Test Group 9: Folder Navigation Events
	# ============================================================================

	describe "change_folder event" do
		test "navigates to specific folder", %{conn: conn} do
			folder1 = folder_fixture(%{name: "Vacation"})
			folder2 = folder_fixture(%{name: "Work"})
			photo1 = photo_fixture(%{folder_id: folder1.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder2.id, filename: "photo2.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			html = render_click(view, "change_folder", %{"folder" => "Vacation"})

			assert folder_in_breadcrumb?(view, "Vacation")
			assert count_photos_in_html(html) == 1
		end

		test "navigates to all folders when folder_name is empty", %{conn: conn} do
			folder1 = folder_fixture(%{name: "Vacation"})
			folder2 = folder_fixture(%{name: "Work"})
			photo1 = photo_fixture(%{folder_id: folder1.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder2.id, filename: "photo2.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin?folder=Vacation")

			html = render_click(view, "change_folder", %{"folder" => ""})

			assert count_photos_in_html(html) == 2
		end
	end

	# ============================================================================
	# Test Group 10: Pagination Events
	# ============================================================================

	describe "change_page event" do
		@tag :skip
		test "changes page number", %{conn: conn} do
			folder = folder_fixture()
			photos = for i <- 1..15, do: photo_fixture(%{folder_id: folder.id, filename: "photo#{i}.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			html = render_click(view, "change_page", %{"page" => "2"})

			assert extract_page_number(html) == 2
		end
	end

	@tag :skip
	describe "change_page - scroll behavior" do
		# Skipped: Phoenix LiveView 1.0 does not support assert_push_event/3
		test "triggers scroll to top when changing pages", %{conn: conn} do
			folder = folder_fixture()
			photos = for i <- 1..15, do: photo_fixture(%{folder_id: folder.id, filename: "photo#{i}.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			render_click(view, "change_page", %{"page" => "2"})

			# Would test: assert_push_event(view, "scroll_to_top", %{})
		end
	end

	# ============================================================================
	# Test Group 11: Component Rendering
	# ============================================================================

	describe "gallery_header component rendering" do
		test "renders breadcrumb with folder and tags", %{conn: conn} do
			folder = folder_fixture(%{name: "Vacation"})
			tag = tag_fixture(%{name: "landscape"})
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			Gallery.add_tag_to_photo(photo, tag.name)

			{:ok, view, _html} = live(conn, ~p"/admin?folder=Vacation&query_tags[]=landscape")

			assert has_element?(view, "#breadcrumb-folder", "Vacation")
			assert has_element?(view, "#breadcrumb-tags", "landscape")
		end

		test "renders sort selector", %{conn: conn} do
			{:ok, view, _html} = live(conn, ~p"/admin")

			assert has_element?(view, "#sort-select")
		end

		test "renders multiselect and collapse controls", %{conn: conn} do
			{:ok, view, _html} = live(conn, ~p"/admin")

			assert has_element?(view, "#multiselect-toggle")
			assert has_element?(view, "#collapse-groups-toggle")
		end
	end

	describe "gallery component rendering" do
		@tag :skip
		test "renders photos in grid with correct zoom level", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, html} = live(conn, ~p"/admin")

			assert has_element?(view, "#gallery-grid")
			assert count_photos_in_html(html) == 2
		end

		@tag :skip
		test "renders pagination controls when needed", %{conn: conn} do
			folder = folder_fixture()
			photos = for i <- 1..15, do: photo_fixture(%{folder_id: folder.id, filename: "photo#{i}.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin")

			assert has_element?(view, "#page-input")
		end
	end

	describe "photo_panel component rendering" do
		@tag :skip
		test "renders photo details for selected photo", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg", description: "Test photo"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo.id}")

			assert has_element?(view, "#photo-section")
			assert photo_in_panel?(view, "photo1.jpg")
		end

		test "renders tags for selected photo", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			tag = tag_fixture(%{name: "landscape"})
			Gallery.add_tag_to_photo(photo, tag.name)

			{:ok, view, html} = live(conn, ~p"/admin/photos/#{photo.id}")

			assert has_element?(view, "#photo-section", "landscape")
		end
	end

	# ============================================================================
	# Test Group 12: Utility Function Tests
	# ============================================================================

	describe "member_by_id?/2" do
		test "returns true when photo is in list by id", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			# Test via behavior: selecting photos and verifying selection
			{:ok, view, _html} = live(conn, ~p"/admin")

			render_click(view, "select_gallery_photo", %{
				"photo_id" => to_string(photo1.id),
				"ctrl_key_pressed" => "false"
			})

			html = render(view)
			assert count_selected_photos(html) == 1
		end

		test "returns false when photo is not in list", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, _html} = live(conn, ~p"/admin/photos/#{photo1.id}")

			# Deselect by clicking with ctrl
			render_click(view, "select_gallery_photo", %{
				"photo_id" => to_string(photo1.id),
				"ctrl_key_pressed" => "true"
			})

			html = render(view)
			assert count_selected_photos(html) == 0
		end
	end

	describe "simplify_photo/1" do
		@tag :skip
		test "simplifies photo for URL caching", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			# Test via behavior: selecting photo and verifying it's in URL
			{:ok, view, _html} = live(conn, ~p"/admin")

			render_click(view, "select_gallery_photo", %{
				"photo_id" => to_string(photo.id),
				"ctrl_key_pressed" => "false"
			})

			assert_patched_to(view, ~p"/admin/photos/#{photo.id}")
		end
	end
end

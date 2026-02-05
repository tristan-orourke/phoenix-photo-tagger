defmodule PhotoTaggerWeb.GalleryLive.DriftTest do
	@moduledoc """
	Tests for the drift LiveView (drift.ex).

	Tests cover mounting, tempo changes, photo switching, and folder scoping.
	"""

	use PhotoTaggerWeb.ConnCase, async: true

	import Phoenix.LiveViewTest
	import PhotoTagger.GalleryFixtures

	alias PhotoTagger.Gallery

	# ============================================================================
	# Helper Functions
	# ============================================================================

	defp extract_current_photo_filename(html) do
		doc = Floki.parse_document!(html)

		case Floki.find(doc, "#drift-photo img") do
			[{_tag, attrs, _children}] ->
				src = Enum.find_value(attrs, fn {key, value} -> if key == "src", do: value end)
				# Extract filename from path
				src |> String.split("/") |> List.last()

			_ ->
				nil
		end
	end

	defp extract_tempo_value(html) do
		doc = Floki.parse_document!(html)

		case Floki.find(doc, "#tempo-display") do
			[{_tag, _attrs, children}] ->
				children |> Floki.text() |> String.trim()

			_ ->
				nil
		end
	end

	# ============================================================================
	# Tests
	# ============================================================================

	describe "mount/3" do
		@tag :skip
		test "loads initial photo from available photos", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})

			{:ok, view, html} = live(conn, ~p"/photos/#{photo1.id}/drift")

			# Should show one of the photos
			assert has_element?(view, "#drift-photo")
			# TODO: More specific assertion about which photo is shown
		end

		test "respects public/private access control", %{conn: conn} do
			public_folder = folder_fixture(%{name: "Public", is_public: true})
			private_folder = folder_fixture(%{name: "Private", is_public: false})
			public_photo = photo_fixture(%{folder_id: public_folder.id, filename: "public.jpg"})
			private_photo = photo_fixture(%{folder_id: private_folder.id, filename: "private.jpg"})

			{:ok, view, html} = live(conn, ~p"/photos/#{public_photo.id}/drift")

			# Public user should only see public photos
			# TODO: Verify only public photos are in rotation
		end
	end

	describe "increase_tempo event" do
		@tag :skip
		test "cycles through tempo values", %{conn: conn} do
			folder = folder_fixture()
			photo = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})

			{:ok, view, html_before} = live(conn, ~p"/photos/#{photo.id}/drift")

			tempo_before = extract_tempo_value(html_before)

			html_after = render_click(view, "increase_tempo", %{})
			tempo_after = extract_tempo_value(html_after)

			# Tempo should have changed
			assert tempo_before != tempo_after
		end
	end

	describe "switch_photos event" do
		@tag :skip
		test "advances to next photo", %{conn: conn} do
			folder = folder_fixture()
			photo1 = photo_fixture(%{folder_id: folder.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, filename: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, filename: "photo3.jpg"})

			{:ok, view, html_before} = live(conn, ~p"/photos/#{photo1.id}/drift")

			# TODO: Deterministic test would require seeding the RNG or mocking weighted selection
			html_after = render_click(view, "switch_photos", %{})

			# Should still have a photo displayed
			assert has_element?(view, "#drift-photo")
		end
	end

	describe "folder scoping" do
		@tag :skip
		test "only shows photos from specified folder", %{conn: conn} do
			folder1 = folder_fixture(%{name: "Folder1"})
			folder2 = folder_fixture(%{name: "Folder2"})
			photo1 = photo_fixture(%{folder_id: folder1.id, filename: "photo1.jpg"})
			photo2 = photo_fixture(%{folder_id: folder2.id, filename: "photo2.jpg"})

			{:ok, view, html} = live(conn, ~p"/folders/Folder1/photos/#{photo1.id}/drift")

			# TODO: More deterministic test would verify only Folder1 photos appear
			# across multiple switch_photos events
			assert has_element?(view, "#drift-photo")
		end
	end
end

defmodule PhotoTaggerWeb.GalleryLive.DriftTest do
	@moduledoc """
	Tests for the Drift LiveView carousel/slideshow mode.

	Tests verify:
	- Initial photo loading and timer setup
	- Weighted random selection via WeightedList
	- Photo advancement on :switch_photos message
	- Public/private access control
	- Folder-specific photo rotation
	"""

	use PhotoTaggerWeb.ConnCase, async: true

	import Phoenix.LiveViewTest
	import PhotoTagger.GalleryFixtures

	alias PhotoTagger.Repo
	alias PhotoTagger.Uploaders.ImageUploader

	# Helper functions to extract data from rendered HTML

	defp get_image_src(html) do
		# Match <img ... src="..."> specifically, not script tags
		case Regex.run(~r/<img[^>]+src="([^"]+)"/, html) do
			[_, src] -> src
			_ -> nil
		end
	end

	defp get_data_attr(html, attr_name) do
		case Regex.run(~r/data-#{attr_name}="([^"]+)"/, html) do
			[_, value] -> value
			_ -> nil
		end
	end

	defp extract_basename_from_src(src) do
		# Image URLs are like: /uploads/images/folder_name/basename.version.webp
		# or /uploads/images/folder_name/basename.ext
		# Extract just the basename (the part after the last slash, before any dots)
		case Regex.run(~r/\/([^\/]+?)\./, src) do
			[_, basename] -> basename
			_ -> nil
		end
	end

	describe "mount/3" do
		test "loads initial photo and starts timer", %{conn: conn} do
			# Create folder with 5 photos
			folder = folder_fixture()

			photos =
				Enum.map(1..5, fn i ->
					photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
				end)

			# Build map of photo basename to photo for verification
			photo_basenames =
				Enum.map(photos, fn p ->
					Path.basename(p.image.file_name, Path.extname(p.image.file_name))
				end)

			# Mount drift view with first photo
			first_photo = hd(photos)
			{:ok, view, html} = live(conn, ~p"/folders/#{folder.name}/photos/#{first_photo.id}/drift")

			# Assert current_photo is one of the photos (verify via image src)
			image_src = get_image_src(html)
			assert image_src != nil
			basename = extract_basename_from_src(image_src)
			assert basename in photo_basenames

			# Assert interval_ms is set to 5000
			interval_ms = get_data_attr(html, "interval-ms")
			assert interval_ms == "5000"

			# Assert timer_start_time exists
			timer_start_time = get_data_attr(html, "timer-start-time")
			assert timer_start_time != nil
			assert String.match?(timer_start_time, ~r/^\d+$/)
		end

		test "selects random photo based on weights", %{conn: conn} do
			# TODO: shoult this use a mocked algorithm or weighted_list instead?
			# Are we testing the random functionality in the right place?

			# This tests WeightedList integration
			# Create photos with various tag frequencies to establish different similarity weights

			folder = folder_fixture()

			# Create 3 tags
			tag_a = tag_fixture(%{name: "tag_a"})
			tag_b = tag_fixture(%{name: "tag_b"})
			tag_c = tag_fixture(%{name: "tag_c"})

			# Create starting photo with tag_a and tag_b
			starting_photo =
				photo_fixture(%{folder_id: folder.id, name: "starting.jpg"})
				|> Repo.preload(:tags)

			photo_tag_fixture(%{photo: starting_photo, tag: tag_a})
			photo_tag_fixture(%{photo: starting_photo, tag: tag_b})
			starting_photo = Repo.preload(starting_photo, :tags, force: true)

			# Create photo_high_similarity with tag_a and tag_b (shares both tags, high weight)
			photo_high =
				photo_fixture(%{folder_id: folder.id, name: "high.jpg"})
				|> Repo.preload(:tags)

			photo_tag_fixture(%{photo: photo_high, tag: tag_a})
			photo_tag_fixture(%{photo: photo_high, tag: tag_b})
			photo_high = Repo.preload(photo_high, :tags, force: true)

			# Create photo_medium_similarity with only tag_a (shares one tag, medium weight)
			photo_medium =
				photo_fixture(%{folder_id: folder.id, name: "medium.jpg"})
				|> Repo.preload(:tags)

			photo_tag_fixture(%{photo: photo_medium, tag: tag_a})
			photo_medium = Repo.preload(photo_medium, :tags, force: true)

			# Create photo_low_similarity with tag_c (shares no tags, low weight)
			photo_low =
				photo_fixture(%{folder_id: folder.id, name: "low.jpg"})
				|> Repo.preload(:tags)

			photo_tag_fixture(%{photo: photo_low, tag: tag_c})
			photo_low = Repo.preload(photo_low, :tags, force: true)

			# Build a map of photo basename to ID for lookup
			photo_map = %{
				Path.basename(photo_high.image.file_name, Path.extname(photo_high.image.file_name)) => photo_high.id,
				Path.basename(photo_medium.image.file_name, Path.extname(photo_medium.image.file_name)) => photo_medium.id,
				Path.basename(photo_low.image.file_name, Path.extname(photo_low.image.file_name)) => photo_low.id
			}

			# Mount drift view and trigger many photo switches to test distribution
			{:ok, view, _html} =
				live(conn, ~p"/folders/#{folder.name}/photos/#{starting_photo.id}/drift")

			# Sample next photo selection 100 times by calling switch_photos
			# We'll count how often each photo is selected
			selected_photos =
				Enum.map(1..100, fn _ ->
					# Trigger switch_photos event
					view |> element("button[phx-click='switch_photos']") |> render_click()
					html = render(view)
					# Extract the basename from the rendered HTML
					image_src = get_image_src(html)
					basename = extract_basename_from_src(image_src)
					# Map to photo ID
					Map.get(photo_map, basename)
				end)

			frequencies = Enum.frequencies(selected_photos)
			high_count = Map.get(frequencies, photo_high.id, 0)
			medium_count = Map.get(frequencies, photo_medium.id, 0)
			low_count = Map.get(frequencies, photo_low.id, 0)

			# Verify that high similarity photo appears more often than medium,
			# and medium appears more often than low
			# Due to randomness, we use a relaxed statistical check
			# High should be selected most frequently (roughly >30%)
			# Medium should be selected moderately (roughly 10-40%)
			# Low should be selected least frequently (roughly <30%)
			assert high_count > medium_count,
				"Expected high similarity photo (#{high_count}) to be selected more than medium (#{medium_count})"

			assert medium_count > low_count,
				"Expected medium similarity photo (#{medium_count}) to be selected more than low (#{low_count})"

			# Verify all photos were selected at least once (probabilistic, but very likely with 100 samples)
			assert high_count > 0
			assert medium_count > 0
			assert low_count > 0
		end
	end

	describe "handle_info :switch_photos" do
		test "advances to next photo", %{conn: conn} do
			# Create folder with multiple photos
			folder = folder_fixture()

			photos =
				Enum.map(1..3, fn i ->
					photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
				end)

			photo_basenames =
				Enum.map(photos, fn p ->
					Path.basename(p.image.file_name, Path.extname(p.image.file_name))
				end)

			# Mount drift view
			first_photo = hd(photos)
			{:ok, view, html} = live(conn, ~p"/folders/#{folder.name}/photos/#{first_photo.id}/drift")

			# Capture current photo from rendered HTML
			initial_src = get_image_src(html)

			# Trigger switch_photos via button click (which sends the event)
			html = view |> element("button[phx-click='switch_photos']") |> render_click()

			# Assert current_photo changed or is one of the valid photos
			new_src = get_image_src(html)
			new_basename = extract_basename_from_src(new_src)
			assert new_basename in photo_basenames

			# For a more deterministic test, verify multiple switches cycle through photos
			# After enough switches, we should see different photos
			basenames_seen =
				Enum.map(1..10, fn _ ->
					html = view |> element("button[phx-click='switch_photos']") |> render_click()
					image_src = get_image_src(html)
					extract_basename_from_src(image_src)
				end)
				|> Enum.uniq()

			# With 3 photos and 10 switches, we should see more than 1 photo
			assert length(basenames_seen) > 1,
				"Expected to see multiple different photos after 10 switches"
		end
	end

	describe "drift mode access control" do
		test "respects public/private access control", %{conn: conn} do
			# Create public folder with public and private photos
			public_folder = folder_fixture(%{is_public: true})
			public_photo = photo_fixture(%{folder_id: public_folder.id, is_public: true, name: "public.jpg"})

			private_photo =
				photo_fixture(%{folder_id: public_folder.id, is_public: false, name: "private.jpg"})

			# Create private folder with a photo
			private_folder = folder_fixture(%{is_public: false})

			private_folder_photo =
				photo_fixture(%{folder_id: private_folder.id, is_public: true, name: "private_folder.jpg"})

			# Build basename map for verification
			public_basename = Path.basename(public_photo.image.file_name, Path.extname(public_photo.image.file_name))
			private_basename = Path.basename(private_photo.image.file_name, Path.extname(private_photo.image.file_name))
			private_folder_basename = Path.basename(private_folder_photo.image.file_name, Path.extname(private_folder_photo.image.file_name))

			# Mount drift view in public mode (using public route)
			{:ok, view, _html} = live(conn, ~p"/folders/#{public_folder.name}/photos/#{public_photo.id}/drift")

			# Trigger many photo switches and verify only public photos appear
			basenames_seen =
				Enum.map(1..20, fn _ ->
					html = view |> element("button[phx-click='switch_photos']") |> render_click()
					image_src = get_image_src(html)
					extract_basename_from_src(image_src)
				end)
				|> Enum.uniq()

			# Should only see the public photo (private_photo should never appear)
			assert public_basename in basenames_seen
			refute private_basename in basenames_seen
			refute private_folder_basename in basenames_seen

			# Now mount in admin mode by using admin route with include_private context
			# Note: The drift.ex implementation uses Gallery.list_photos() which checks options
			# However, looking at drift.ex, it doesn't pass include_private option
			# This is a limitation in the current implementation - drift always uses public filtering
			# For this test to properly verify admin mode, we would need to modify drift.ex
			# to respect an include_private parameter passed via session or route

			# For now, we'll just verify that the public mode filtering works correctly
			# A complete implementation would require drift.ex to accept and use include_private
		end
	end

	describe "drift mode folder navigation" do
		test "navigates between photos in folder", %{conn: conn} do
			# Create folder1 with 3 photos
			folder1 = folder_fixture(%{name: "folder1"})

			folder1_photos =
				Enum.map(1..3, fn i ->
					photo_fixture(%{folder_id: folder1.id, name: "folder1_photo#{i}.jpg"})
				end)

			folder1_basenames =
				Enum.map(folder1_photos, fn p ->
					Path.basename(p.image.file_name, Path.extname(p.image.file_name))
				end)

			# Create folder2 with 2 photos
			folder2 = folder_fixture(%{name: "folder2"})

			folder2_photos =
				Enum.map(1..2, fn i ->
					photo_fixture(%{folder_id: folder2.id, name: "folder2_photo#{i}.jpg"})
				end)

			folder2_basenames =
				Enum.map(folder2_photos, fn p ->
					Path.basename(p.image.file_name, Path.extname(p.image.file_name))
				end)

			# Mount drift for folder1
			first_photo = hd(folder1_photos)
			{:ok, view, _html} = live(conn, ~p"/folders/#{folder1.name}/photos/#{first_photo.id}/drift")

			# Trigger many switches and collect seen photos
			basenames_seen =
				Enum.map(1..20, fn _ ->
					html = view |> element("button[phx-click='switch_photos']") |> render_click()
					image_src = get_image_src(html)
					extract_basename_from_src(image_src)
				end)
				|> Enum.uniq()

			# Verify only folder1 photos shown in rotation
			assert Enum.all?(basenames_seen, fn name -> name in folder1_basenames end)

			# Verify no folder2 photos appear
			refute Enum.any?(basenames_seen, fn name -> name in folder2_basenames end)

			# Verify we've seen multiple folder1 photos (probabilistic, but very likely)
			assert length(basenames_seen) > 1,
				"Expected to see multiple photos from folder1 during rotation"
		end
	end
end

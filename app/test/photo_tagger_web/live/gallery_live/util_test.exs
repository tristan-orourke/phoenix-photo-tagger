defmodule PhotoTaggerWeb.GalleryLive.UtilTest do
  @moduledoc """
  Tests for the GalleryLive.Util module, which provides utility functions
  for URL building, integer parsing, and ceiling division.
  """
  use ExUnit.Case, async: true

  alias PhotoTaggerWeb.GalleryLive.Util

  describe "build_url/6" do
    test "generates correct public URLs without admin prefix" do
      url = Util.build_url(nil, [], [], [], false)
      assert url == "/photos"
    end

    test "generates correct admin URLs with admin prefix" do
      url = Util.build_url(nil, [], [], [], true)
      assert url == "/admin/photos"
    end

    test "handles nil folder with no photo" do
      url = Util.build_url(nil, [], [], [], false)
      assert url == "/photos"
    end

    test "handles folder without photo_id" do
      url = Util.build_url("vacation", [], [], [], false)
      assert url == "/folders/vacation"
    end

    test "handles single photo_id in list" do
      url = Util.build_url("vacation", [123], [], [], false)
      assert url == "/folders/vacation/photos/123"
    end

    test "handles photo_id without folder" do
      url = Util.build_url(nil, [456], [], [], false)
      assert url == "/photos/456"
    end

    test "includes query_tags in query string" do
      url = Util.build_url(nil, [], ["nature", "sunset"], [], false)
      assert url =~ "query_tags"
      assert url =~ "nature"
      assert url =~ "sunset"
    end

    test "includes exclude_tags in query string" do
      url = Util.build_url(nil, [], [], ["private", "draft"], false)
      assert url =~ "exclude_tags"
      assert url =~ "private"
      assert url =~ "draft"
    end

    test "includes selected_photos in query string for multiple photos" do
      url = Util.build_url(nil, [1, 2, 3], [], [], false)
      # With multiple photos, none become the photo_id in path
      # selected_photo_ids stays as [1, 2, 3] and goes to query string
      assert url =~ "/photos?"
      assert url =~ "selected_photos"
      assert url =~ "1"
      assert url =~ "2"
      assert url =~ "3"
    end

    test "multiple selected photos appear in query string" do
      url = Util.build_url("folder", [10, 20, 30], [], [], false)
      # Multiple photos: photo_id becomes nil, selected_photo_ids stays as list
      assert url =~ "/folders/folder"
      assert url =~ "selected_photos"
      assert url =~ "10"
      assert url =~ "20"
      assert url =~ "30"
    end

    test "includes sort param only when :date" do
      url_manual = Util.build_url(nil, [], [], [], false, sort: :manual)
      url_date = Util.build_url(nil, [], [], [], false, sort: :date)
      url_nil = Util.build_url(nil, [], [], [], false)

      refute url_manual =~ "sort"
      assert url_date =~ "sort=date"
      refute url_nil =~ "sort"
    end

    test "includes pg param only when greater than 1" do
      url_nil = Util.build_url(nil, [], [], [], false)
      url_page1 = Util.build_url(nil, [], [], [], false, pg: 1)
      url_page2 = Util.build_url(nil, [], [], [], false, pg: 2)
      url_page5 = Util.build_url(nil, [], [], [], false, pg: 5)

      refute url_nil =~ "pg"
      refute url_page1 =~ "pg"
      assert url_page2 =~ "pg=2"
      assert url_page5 =~ "pg=5"
    end

    test "handles tail parameter for drift mode" do
      url = Util.build_url("vacation", [123], [], [], false, tail: "drift")
      assert url == "/folders/vacation/photos/123/drift"
    end

    test "handles tail parameter without folder" do
      url = Util.build_url(nil, [789], [], [], false, tail: "drift")
      assert url == "/photos/789/drift"
    end

    test "combines admin prefix with tail" do
      url = Util.build_url("album", [42], [], [], true, tail: "drift")
      assert url == "/admin/folders/album/photos/42/drift"
    end

    test "combines all parameters correctly" do
      url =
        Util.build_url(
          "summer",
          [100, 200],
          ["beach"],
          ["indoor"],
          true,
          sort: :date,
          pg: 3
        )

      assert url =~ "/admin/folders/summer"
      assert url =~ "query_tags"
      assert url =~ "beach"
      assert url =~ "exclude_tags"
      assert url =~ "indoor"
      assert url =~ "selected_photos"
      assert url =~ "sort=date"
      assert url =~ "pg=3"
    end
  end

  describe "safe_integer_parse/2" do
    test "parses valid integer strings" do
      assert Util.safe_integer_parse("123", 0) == 123
      assert Util.safe_integer_parse("42", -1) == 42
      assert Util.safe_integer_parse("0", 99) == 0
    end

    test "parses negative integer strings" do
      assert Util.safe_integer_parse("-5", 0) == -5
      assert Util.safe_integer_parse("-100", 1) == -100
    end

    test "returns default for invalid input" do
      assert Util.safe_integer_parse("abc", 0) == 0
      assert Util.safe_integer_parse("xyz", 42) == 42
      assert Util.safe_integer_parse("not a number", -1) == -1
    end

    test "handles empty string" do
      assert Util.safe_integer_parse("", 0) == 0
      assert Util.safe_integer_parse("", 99) == 99
    end

    test "handles string with trailing characters" do
      # Integer.parse returns the integer portion before non-digit chars
      assert Util.safe_integer_parse("123abc", 0) == 123
      assert Util.safe_integer_parse("42xyz", -1) == 42
      assert Util.safe_integer_parse("5 items", 0) == 5
    end

    test "handles string with leading whitespace" do
      # Integer.parse does not handle leading whitespace
      assert Util.safe_integer_parse(" 123", 0) == 0
    end
  end

  describe "ceiling_div/2" do
    test "calculates ceiling division with no remainder" do
      assert Util.ceiling_div(9, 3) == 3
      assert Util.ceiling_div(10, 5) == 2
      assert Util.ceiling_div(100, 10) == 10
    end

    test "calculates ceiling division with remainder" do
      assert Util.ceiling_div(10, 3) == 4
      assert Util.ceiling_div(7, 2) == 4
      assert Util.ceiling_div(11, 5) == 3
    end

    test "handles dividend of 0" do
      assert Util.ceiling_div(0, 5) == 0
      assert Util.ceiling_div(0, 1) == 0
      assert Util.ceiling_div(0, 100) == 0
    end

    test "handles dividend equal to divisor" do
      assert Util.ceiling_div(5, 5) == 1
      assert Util.ceiling_div(1, 1) == 1
      assert Util.ceiling_div(42, 42) == 1
    end

    test "handles dividend smaller than divisor" do
      assert Util.ceiling_div(1, 5) == 1
      assert Util.ceiling_div(3, 10) == 1
      assert Util.ceiling_div(1, 100) == 1
    end

    test "handles divisor of 1" do
      assert Util.ceiling_div(5, 1) == 5
      assert Util.ceiling_div(42, 1) == 42
      assert Util.ceiling_div(0, 1) == 0
    end
  end
end

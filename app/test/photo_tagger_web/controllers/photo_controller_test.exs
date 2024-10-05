defmodule PhotoTaggerWeb.PhotoControllerTest do
  use PhotoTaggerWeb.ConnCase

  import PhotoTagger.GalleryFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  describe "index" do
    test "lists all photos", %{conn: conn} do
      conn = get(conn, ~p"/photos")
      assert html_response(conn, 200) =~ "Listing Photos"
    end
  end

  describe "new photo" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/photos/new")
      assert html_response(conn, 200) =~ "New Photo"
    end
  end

  describe "create photo" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/photos", photo: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/photos/#{id}"

      conn = get(conn, ~p"/photos/#{id}")
      assert html_response(conn, 200) =~ "Photo #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/photos", photo: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Photo"
    end
  end

  describe "edit photo" do
    setup [:create_photo]

    test "renders form for editing chosen photo", %{conn: conn, photo: photo} do
      conn = get(conn, ~p"/photos/#{photo}/edit")
      assert html_response(conn, 200) =~ "Edit Photo"
    end
  end

  describe "update photo" do
    setup [:create_photo]

    test "redirects when data is valid", %{conn: conn, photo: photo} do
      conn = put(conn, ~p"/photos/#{photo}", photo: @update_attrs)
      assert redirected_to(conn) == ~p"/photos/#{photo}"

      conn = get(conn, ~p"/photos/#{photo}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, photo: photo} do
      conn = put(conn, ~p"/photos/#{photo}", photo: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Photo"
    end
  end

  describe "delete photo" do
    setup [:create_photo]

    test "deletes chosen photo", %{conn: conn, photo: photo} do
      conn = delete(conn, ~p"/photos/#{photo}")
      assert redirected_to(conn) == ~p"/photos"

      assert_error_sent 404, fn ->
        get(conn, ~p"/photos/#{photo}")
      end
    end
  end

  defp create_photo(_) do
    photo = photo_fixture()
    %{photo: photo}
  end
end

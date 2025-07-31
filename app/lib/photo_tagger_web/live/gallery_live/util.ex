defmodule PhotoTaggerWeb.GalleryLive.Util do
  def build_url(folder, selected_photo_ids, tags, is_admin, tail \\ nil) do
    {photo_id, selected_photo_ids} =
      case selected_photo_ids do
        [photo_id] -> {photo_id, []}
        photo_ids -> {nil, photo_ids}
      end

    uri =
      case is_admin do
        true -> "/admin"
        false -> ""
      end
      |> Kernel.<>(
        case {folder, photo_id} do
          {nil, nil} -> URI.encode("/photos")
          {folder, nil} -> URI.encode("/folders/#{folder}")
          {nil, photo_id} -> URI.encode("/photos/#{photo_id}")
          {folder, photo_id} -> URI.encode("/folders/#{folder}/photos/#{photo_id}")
        end
      )
      |> Kernel.<>(
        case tail do
          nil -> ""
          _ -> URI.encode("/#{tail}")
        end
      )
      |> URI.new!()

    query =
      %{}
      |> Map.put(:query_tags, tags)
      |> Map.put(:selected_photos, selected_photo_ids)
      |> Plug.Conn.Query.encode()

    uri =
      case query do
        "" -> uri
        _ -> URI.append_query(uri, query)
      end

    URI.to_string(uri)
  end
end

defmodule PhotoTaggerWeb.GalleryLive.Util do
  require Logger

  @default_pg_size 500

  def build_url(folder, selected_photo_ids, tags, exclude_tags, is_admin, opts \\ []) do
    tail = Keyword.get(opts, :tail)
    sort = Keyword.get(opts, :sort)
    pg = Keyword.get(opts, :pg)
    sort_direction = Keyword.get(opts, :sort_direction)
    pg_size = Keyword.get(opts, :pg_size)

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
      |> Map.put(:exclude_tags, exclude_tags)
      |> Map.put(:selected_photos, selected_photo_ids)
      |> then(fn q ->
        case sort do
          :date -> Map.put(q, :sort, "date")
          _ -> q
        end
      end)
      |> then(fn q ->
        case sort_direction do
          :asc -> Map.put(q, :sort_direction, "asc")
          _ -> q
        end
      end)
      |> then(fn q ->
        case pg do
          nil -> q
          1 -> q
          _ -> Map.put(q, :pg, pg)
        end
      end)
      |> then(fn q ->
        case pg_size do
          nil -> q
          @default_pg_size -> q
          _ -> Map.put(q, :pg_size, pg_size)
        end
      end)
      |> Plug.Conn.Query.encode()

    uri =
      case query do
        "" -> uri
        _ -> URI.append_query(uri, query)
      end

    URI.to_string(uri)
  end

  def safe_integer_parse(value, default) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  def ceiling_div(dividend, divisor) do
    Logger.debug("Ceiling division: #{dividend} / #{divisor}")
    remainder = rem(dividend, divisor)

    result =
      if remainder == 0 do
        div(dividend, divisor)
      else
        div(dividend, divisor) + 1
      end

    Logger.debug("Ceiling division result: #{result}")
    result
  end
end

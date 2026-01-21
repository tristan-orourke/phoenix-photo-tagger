# Plan: Admin Gallery Public/Private Visibility Indicator

## Summary

Add a toggle button in admin gallery view that displays colored outlines around photos to show their public/private status:
- **GREEN ring**: Public photos (`is_public = true`)
- **RED ring**: Private photos (`is_public = false`)

The toggle is session-only (resets on page refresh) and admin-only.

---

## Files to Modify

1. `app/lib/photo_tagger_web/live/gallery_live/main.ex` - Main LiveView
2. `app/lib/photo_tagger_web/live/gallery_live/gallery_photo.ex` - Photo component
3. `app/assets/tailwind.config.js` - Safelist (if needed)

---

## Implementation Steps

### Step 1: Update `simplify_photo/1` to include `is_public`

**File:** `main.ex` (line ~1514)

```elixir
# From:
def simplify_photo(photo), do: Map.take(photo, [:id, :name, :group, :image, :folder])

# To:
def simplify_photo(photo), do: Map.take(photo, [:id, :name, :group, :image, :folder, :is_public])
```

### Step 2: Add socket assign in `mount/3`

**File:** `main.ex` (line ~168)

Add after `assign(:zoom_level, 0)`:
```elixir
|> assign(:show_visibility_indicator, false)
```

### Step 3: Add event handler

**File:** `main.ex` (after `toggle_multiselect` handler, ~line 1171)

```elixir
def handle_event("toggle_visibility_indicator", _params, socket) do
	{:noreply, assign(socket, :show_visibility_indicator, !socket.assigns.show_visibility_indicator)}
end
```

### Step 4: Add toggle button to `gallery_header`

**File:** `main.ex`

Add attribute (~line 458):
```elixir
attr(:show_visibility_indicator, :boolean, default: false)
```

Add button after the Multiselect toggle button (~line 531):
```elixir
<.toggle_button
	:if={@is_admin}
	selected={@show_visibility_indicator}
	phx-click="toggle_visibility_indicator"
	class="flex items-center pl-3 pr-3 inline ml-1"
>
	<.icon name="hero-eye" class="hero-eye-mini lg:hero-eye my-1 lg:my-0 w-4 h-4 lg:w-5 lg:h-5" />
	<span class="sr-only lg:not-sr-only lg:ml-1">
		{if(@show_visibility_indicator, do: "Hide visibility", else: "Show visibility")}
	</span>
</.toggle_button>
```

### Step 5: Pass props through component chain

**5a.** Update `gallery_header` call in `render/1` (~line 38):
```elixir
show_visibility_indicator={@show_visibility_indicator}
```

**5b.** Update `gallery` call in `render/1` (~line 59):
```elixir
show_visibility_indicator={@show_visibility_indicator}
```

**5c.** Add attribute to `gallery` component (~line 586):
```elixir
attr(:show_visibility_indicator, :boolean, default: false)
```

**5d.** Pass to `GalleryPhoto` live_component (~line 646):
```elixir
photo_is_public={photo.is_public}
show_visibility_indicator={@show_visibility_indicator}
```

### Step 6: Update `GalleryPhoto` component

**File:** `gallery_photo.ex`

**6a.** Add attributes:
```elixir
attr(:photo_is_public, :boolean, default: false)
attr(:show_visibility_indicator, :boolean, default: false)
```

**6b.** Add helper function:
```elixir
defp visibility_indicator_class(show_indicator, is_public) do
	case {show_indicator, is_public} do
		{true, true} -> "ring-4 ring-inset ring-green-500"
		{true, false} -> "ring-4 ring-inset ring-red-500"
		{false, _} -> ""
	end
end
```

**6c.** Update button class in render to include:
```elixir
#{visibility_indicator_class(@show_visibility_indicator, @photo_is_public)}
```

### Step 7: Tailwind safelist (if needed)

**File:** `tailwind.config.js`

If ring colors are purged, add to safelist:
```javascript
'ring-green-500',
'ring-red-500',
'ring-4',
'ring-inset',
```

---

## Visual Behavior

- Using `ring-inset` places the colored ring **inside** the photo
- Selection uses `outline-offset-2` which places the blue outline **outside** the photo
- Both can be visible simultaneously without conflict

| State | Selection | Visibility Ring |
|-------|-----------|-----------------|
| Not selected, indicator off | None | None |
| Selected, indicator off | Blue outline | None |
| Not selected, indicator on, public | None | Green ring |
| Not selected, indicator on, private | None | Red ring |
| Selected + indicator on | Blue outline | Green/Red ring |

---

## Verification

1. Start dev server: `docker-compose -f docker-compose-dev.yml run --user $(id -u):$(id -g) app mix phx.server`
2. Navigate to admin gallery view (any folder or root)
3. Verify toggle button appears in header toolbar (admin-only)
4. Click toggle - photos should show green (public) or red (private) rings
5. Select a photo - verify blue selection outline coexists with colored ring
6. Toggle off - rings should disappear
7. Verify toggle does NOT appear in public view (`/` route)
8. Run tests: `mix test`

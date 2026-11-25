# Map Editor UI Improvement Plan

The current editor is functional but dense: eleven terrain brushes, four team
spawns, four deposit tools, metadata, file/share-code actions, validation and
test-play all compete for two horizontal rows. The first pass keeps the existing
keyboard/mouse model and fixes the highest-risk workflow (save/load feedback);
the follow-up phases below are the fuller redesign.

## Phase 1 — shipped with this pass

- **Explicit map path.** A `Map File:` field replaces guessing the file name
  from the map title. `Save As…`, `Load`, and `Load Quick Map` all state the
  exact path or reason for failure.
- **Structured errors.** `MapSerializer.save_with_result()`,
  `load_with_result()`, `validate_detailed()`, and
  `from_share_code_detailed()` replace silent `null`/error-code returns. The
  editor shows the reason verbatim, color-coded as info/success/warning/error.
- **Safe test play.** Test play writes a temporary `.bwm` without replacing the
  main menu's quick-load map; if that write fails, the match is not started.
- **Share-code diagnostics.** Import failures explain whether the code is
  empty, mis-prefixed, truncated, non-Base64, non-JSON, or has bad tile data.
- **Load validation warning.** A syntactically valid but unplayable map loads
  with a warning instead of being silently accepted or rejected.

## Phase 2 — workspace layout

Split the single canvas into three named panels using a `HSplitContainer`:

1. **Tool rail (left, ~220 px).** Scrollable `VBoxContainer` with sections:
   - `Terrain` — grouped brush buttons; active brush highlighted.
   - `Markers` — HQ Team 0–3, Oil/Iron/Geo/Food deposits, Erase.
   - `Brush` — radius slider (1–4), Fill, Mirror-X, Mirror-Y toggles.
2. **Canvas (center).** Hex cursor, hover coordinates, grid overlay toggle,
   zoom controls, and a small legend for team colors/resource markers.
3. **Inspector (right, ~280 px).** Metadata, map statistics, validation
   checklist, file path, share code, and recent status history.

Use a top menu bar (`File`, `Edit`, `View`, `Map`, `Help`) with accelerators so
the canvas is not crowded. Keep `Esc` for cancel/pause, `WASD/Arrows` for pan,
and mouse wheel for zoom.

## Phase 3 — safer file workflows

- Replace the raw path field with a `FileDialog` filtered to `*.bwm`,
  pre-filled from `MapSerializer.MAPS_DIR`, while keeping the path visible for
  copy/paste and automation.
- Add **Save**, **Save As…**, **Load Recent…**, and **New Map** with an
  unsaved-changes badge (`dirty` flag set by paint/marker/metadata edits).
- Show a confirmation dialog before discarding unsaved changes or overwriting
  an existing file.
- Store a short recent-files list in `SettingsManager` and display it in the
  `File` menu.

## Phase 4 — validation and collaboration

- Replace the single status line with a persistent `ValidationPanel` checklist:
  dimensions, ≥64 land tiles, connected land mass, spawn count/balance,
  deposit count, and passability of each HQ. Each row shows OK/FAIL with the
  exact reason from `MapData.validate_map()`.
- Add **Copy Share Code**, **Import Share Code**, and **Import from URL**, all
  using the same detailed result object so failures are actionable.
- Add map thumbnails to the recent list using the existing thumbnail generator.
- Add an undo/redo stack (terrain strokes and marker edits) with `Ctrl+Z` /
  `Ctrl+Shift+Z`, and expose `MapSerializer.validate_detailed()` to a CLI
  preflight used by CI.

## Acceptance criteria

- Every save/load/share-code failure names the operation, path/code prefix,
  and specific cause; no generic "failed" or silent `null`.
- A user can identify the active tool, brush size, map path, dirty state, and
  validation status without opening a dialog.
- Test play never overwrites the quick-load map and refuses to start when the
  temporary save fails.
- New GUT coverage exercises success and each structured error branch.

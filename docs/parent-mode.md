# Parent mode

A gesture-gated area for local, on-device settings, kept out of reach of the
toddler audience: tap the background 5 times to open a code challenge, enter
the code to reach a settings screen. Settings persist locally via a generic
autoload and survive a restart.

## Entry gesture and why `Layout`'s `mouse_filter` matters

`TapGestureDetector` (`scripts/parent/tap_gesture_detector.gd`) is attached
directly as `Background`'s own script in `scenes/main.tscn` — the same
"class_name'd script on an inline scene node" pattern `Main` itself uses,
rather than a separate component scene. It counts taps via `gui_input`,
resetting the count if the gap since the previous tap exceeds
`tap_reset_window` (`@export`, default 1.5s), and emits `gate_requested`
once `required_taps` (default 5) land inside that window.

Three `mouse_filter` changes were needed together, not one:
- `Background`: `IGNORE` → `STOP`, so it can receive `gui_input` at all.
- `Layout` (the full-screen `MarginContainer`) **and** `Center` (the
  `CenterContainer` inside it): default → `IGNORE` on both. Every
  `Control`-derived container defaults to `STOP`, and both of these fill
  nearly the whole screen — not just `Layout` (obviously full-rect), but
  also `Center`: a `CenterContainer` gets *stretched by its parent
  `MarginContainer` to fill the entire available rect* and merely centers
  its child within that rect, it does not shrink itself down to the child's
  size. So `Center`'s own hit-test rect is nearly the full screen too, and
  it was the one actually swallowing almost every tap in practice (`Layout`
  alone wasn't enough to fix the gesture — a first pass that changed only
  `Layout` still left taps dead almost everywhere, since `Center` sat right
  behind it blocking the same area). Only `CardGrid` (inside `Center`) is
  genuinely tight-wrapped to just the card grid, since `CenterContainer`
  doesn't stretch *that* child — its still-default `STOP` there is a
  legitimate, small, accepted gap (the narrow gutters between cards).
  Card taps themselves aren't affected by any of this: `WordCard`'s own
  `TextureButton` still wins wherever a card actually sits, since Godot
  checks children before falling back to a container's own input handling.

## The gate: code, countdown, retry

`ParentGate` (`scenes/parent/parent_gate.tscn` /
`scripts/parent/parent_gate.gd`) is not a real password screen — the code is
shown right on screen. It works as a gate purely because the target
audience (toddlers) can't reliably read a 2-digit number or operate a
keypad. `ParentGate.CODE_LENGTH` is the one place that digit count lives —
`_generate_code()`, the entry-length check, and the dot-slot display all
read it rather than hard-coding `2`. Wrong entries clear and let the parent
retry the *same* code; only a manual cancel or the deadline expiring closes
it.

The 15-second deadline is driven by a `create_tween().tween_method(...)`
animating a countdown value from `deadline_seconds` to `0`, rather than a
`Timer` node (none exist elsewhere in this codebase) or a bare
`await get_tree().create_timer(...).timeout`. One mechanism gets three
things for free: a live countdown bar/label, trivial cancel-on-success
(`tween.kill()`), and a natural expiry signal (`tween.finished`).

`deadline_seconds` is deliberately **not** consumed in `_ready()` — it's
read when `start()` is called, which `ParentModeCoordinator` calls right
after `add_child()`. This split exists so a test can set a tiny
`deadline_seconds` before `start()` runs, instead of eating a real 15-second
wait per test run. **Don't collapse `start()` back into `_ready()`** — that
would silently reintroduce the wall-clock cost documented in
`docs/testing.md`'s guidance on keeping timer-heavy tests cheap.

## Layout: fitting a landscape screen

Both `ParentGate` and `ParentSettings` originally used a single tall
`VBoxContainer` stack (title → instruction → code → countdown → digits →
3-column/4-row keypad → button), sized via a fixed-pixel
`custom_minimum_size` and centered with a plain `CenterContainer`. That
easily exceeds a landscape phone's available *height* (this project is
locked to landscape — see `window/handheld/orientation` in
`project.godot`), and `CenterContainer` doesn't clip or shrink oversized
content, it just centers it — so an over-tall panel overflows evenly past
*both* the top and bottom edges, which is exactly how a real device ended
up with the title cut off at the top and the bottom button cut off at the
same time.

Two changes fix this:

- **Compact, wide content instead of tall content.** The gate's content is
  now two side-by-side columns (code/countdown on the left, a 5×2 numeric
  keypad + backspace/cancel row on the right) instead of one tall stack with
  a 3×4 keypad — landscape has width to spare, so trading height for width
  is the natural fix. This alone gets the natural (minimum) content size
  down to roughly 700×290, comfortably under any realistic landscape
  viewport.
- **Percentage anchors instead of a fixed pixel size.** `PanelContainer` is
  anchored to `(0.08, 0.06)–(0.92, 0.94)` of the screen — i.e. always ~84%
  width / ~88% height of whatever the real viewport is — instead of a fixed
  `custom_minimum_size`. This is what actually makes the panel *responsive*:
  it scales with the device rather than assuming one fixed reference
  resolution. `clip_contents = true` on `PanelContainer` is a deliberate
  defensive backstop for the (should-be-rare, given the point above)
  situation where content still doesn't fit even that generous a share of
  the screen — Godot never shrinks a control below its content's minimum
  size no matter what the anchors say, so on some hypothetical very small
  device the panel could still grow past the anchor rect; `clip_contents`
  ensures that shows as content quietly clipped at the panel edge rather
  than the original bug's silent full-content overflow past both edges.

**A `ScrollContainer` was tried and deliberately removed.** The instinct to
wrap the content in a `ScrollContainer` as an additional safety net (scroll
instead of clip) turned out to interact badly with the anchored
`PanelContainer` in this Godot version — nesting a `CenterContainer` with
expand/fill size flags inside a `ScrollContainer` produced runaway,
non-deterministic layout sizes (900–1000px+ on axes that should have been a
few hundred), which only showed up when actually measuring computed sizes
at runtime, not from reading the `.tscn` itself. Given the two fixes above
already make overflow unlikely in practice, the simpler
anchors+`clip_contents` combination (no `ScrollContainer`) was kept instead
of chasing that interaction further — if a future change reintroduces a
`ScrollContainer` here, verify actual computed sizes at runtime (e.g. via a
throwaway `SceneTree` script printing `Control.size` after a few
`await process_frame`s), not just visually or by reading the scene file.

Both screens' `%UniqueName` nodes were preserved through this restructuring,
so `parent_gate.gd`/`parent_settings.gd` needed no changes — only the
`.tscn` node tree moved.

## Exiting parent mode: restart, don't resume

`ParentModeCoordinator` (`scripts/parent/parent_mode_coordinator.gd`) pauses
the tree (`get_tree().paused = true`) while the gate or settings overlay is
open — both scenes' root nodes are `process_mode = PROCESS_MODE_ALWAYS` so
they keep working through the pause, while `Main`'s own `Tween`-driven
animations and `WordCard` button input correctly freeze (both default to a
pausable `process_mode`, and `create_tween()` defaults to
`TWEEN_PAUSE_BOUND`).

One thing pausing does *not* freeze automatically: `SceneTree.create_timer()`
defaults `process_always` to `true`, meaning a bare
`await get_tree().create_timer(seconds).timeout` keeps counting down (and
firing) through a pause by default. `Main`'s three round-advance delays
(`start_round`, `_watch_for_no_answer`, `_on_card_selected`) all pass
`process_always=false` explicitly for exactly this reason: without it, a new
word prompt (or a `retry_delay` re-prompt) could fire — and play audio —
*while the gate or settings screen is on top of it*, which is exactly the
bug this was caught by. This is a small, deliberate, documented exception to
generally not touching `main.gd`'s core game-loop code for this feature's
sake; every other exit path just calls `get_tree().reload_current_scene()`.

`AudioStreamPlayer` playback isn't driven by per-frame processing at all, so
it isn't affected by `process_always` either way — `ParentModeCoordinator`
separately, defensively stops both `%WordAudioPlayer` and
`%PraiseAudioPlayer` the moment the gate opens, so a clip that was *already*
mid-playback at the exact instant of the 5th tap doesn't keep playing under
the overlay. Between the two fixes, no game audio should play at all while
parent mode is open.

Every exit path from parent mode — gate cancelled/timed out, or settings
closed — calls `get_tree().reload_current_scene()` after unpausing. This
rebuilds `Main` (and a fresh `TapGestureDetector`/`ParentModeCoordinator`)
from scratch rather than trying to resume the interrupted round in place,
which is also the natural point to pick up any settings just saved.
`reload_current_scene` is called deferred
(`get_tree().reload_current_scene.call_deferred()`) since it's triggered
from inside a signal callback on a node that's about to be torn down along
with the rest of the scene.

## Local settings storage

The `Settings` autoload (`scripts/settings.gd`) is a generic key/value store
backed by `ConfigFile` at `user://settings.cfg` (`Settings.DEFAULT_PATH`):

```gdscript
Settings.get_value("some_key", default_value)
Settings.set_value("some_key", new_value)   # writes to disk immediately
```

**Tests must never let this touch a developer's real save file.** Several
tests simulate a real tap through `ParentSettings`' actual production
signal handlers (e.g. `.pressed.emit()` on a card-count button), which
correctly calls `Settings.set_value()` with its default `persist=true` —
that's the real, intended behavior being tested, not a test mistake, so
`persist: false` discipline in the test itself doesn't help here. Any test
suite that exercises those code paths (or otherwise touches `Settings`)
must redirect it first:

```gdscript
const SCRATCH_PATH := "user://test_settings.cfg"

func before() -> void:      # once per suite, not per test
    Settings.use_path_for_testing(SCRATCH_PATH)

func after() -> void:
    Settings.use_path_for_testing(Settings.DEFAULT_PATH)
    # ...and delete the scratch file (see any of the test files below).
```

This was **missed initially** — for a while, running this project's own
test suite repeatedly (as happened a lot while building this feature) was
quietly overwriting the real `user://settings.cfg` on whatever machine ran
it, with whatever values the most recently added persist=true test path
happened to leave behind. That's a very plausible explanation for a "the
default should be X but shows Y" report that has nothing to do with the
production code being wrong.

**To add a setting, two things need to happen, not one:**

1. **The UI that writes it:** add a control under `%ContentContainer` in
   `scenes/parent/parent_settings.tscn`, and wire it directly to
   `Settings.get_value`/`set_value` in `parent_settings.gd`.
2. **Whatever gameplay code the setting is supposed to affect has to read
   it back.** This part is unavoidable and setting-specific — there's no
   way around *some* code elsewhere needing to consume the value. The
   card-count setting (`SettingsKeys.CARD_COUNT`, the first real setting
   added) is the worked example: `ParentSettings._setup_card_count_row()`
   writes it, and `Main._apply_stored_card_count()` reads it back at the
   start of `Main._ready()`, overriding `@export var image_count` before
   `spawn_board()` runs. Since exiting parent mode always calls
   `get_tree().reload_current_scene()` (see above), a newly-picked value
   takes effect automatically on the very next `_ready()` — no extra
   "apply now" plumbing needed.

Put the key string itself in `scripts/parent/settings_keys.gd`
(`class_name SettingsKeys`, plain constants, no autoload) rather than
literal `"card_count"`-style strings in both the writer and the reader —
it's the one thing a typo in either file would silently break (the setting
would just always read back as its default, no error). Add a new
`const` there for each new setting.

Because a stored value is Variant data from a file that could in principle
be missing, stale, or hand-edited, whatever reads it back must validate
before trusting it (matching the "best-effort, must not crash" framing
below) — see `Main._apply_stored_card_count()`'s `stored is int and stored
> 0` guard for the pattern to follow.

**Persistence means what it says: a saved value stays saved.**
`Settings.set_value()` defaults to `persist: true` and writes to real disk
on every call, including from a `pressed` signal fired by an ordinary tap —
there's no separate "confirm"/"apply" step. So if a parent taps a
non-default option while just trying the UI out, that becomes the real
saved value from then on, across restarts, until something explicitly picks
a different one again. That's the intended behavior (the whole point of
persistence), not a bug — but it's easy to mistake for one while testing
("I set it to 12 in the Inspector default, why did it come back as
something else"), so it's worth remembering this explicitly rather than
re-diagnosing it each time.

### Worked example: card count and its board shape (`BoardLayout`)

The card-count setting doesn't just pick a total; the board's grid shape
(columns, and therefore rows) has to follow it too, and the settings
screen shows that shape rather than a bare number (a parent picks "a
3x4 board", not "12"). Both of those — `Main`'s actual grid columns and
`ParentSettings`'s button labels — come from one shared mapping,
`scripts/parent/board_layout.gd` (`class_name BoardLayout`, a `RefCounted`
with only `static func`s, no autoload needed since it's stateless):

```gdscript
const OPTIONS: Array[Dictionary] = [
    {"count": 9, "columns": 3},
    {"count": 12, "columns": 4},
    {"count": 15, "columns": 5},
]
static func columns_for(count: int, fallback_columns: int) -> int: ...
static func label_for(count: int) -> String: ...  # "RxC", e.g. 9 -> "3x3"
```

Rows are always `count / columns` — there's no independent rows setting.
`Main._ready()` calls `columns = BoardLayout.columns_for(image_count,
columns)` **before** `card_grid.columns = columns`, and critically updates
the `columns` *member itself*, not just `card_grid.columns` — `_slot_offset()`
(used by `reroll_board()`'s animation math) reads `columns` directly, so if
only `card_grid.columns` were updated the reroll animation would silently
use the wrong grid shape for any non-default count. `columns_for`'s
`fallback_columns` parameter (`Main`'s own `@export var columns`) is what
keeps a manually-tuned `image_count` outside the three parent-offered
options from erroring — it just falls back to whatever the Inspector says
rather than requiring every possible count to have a defined shape.

`ParentSettings._setup_card_count_row()` reads each button's *node name*
(e.g. `"CardCount9"` → `9`) to get its value, not its displayed text — the
text is now the "RxC" label, and all three labels currently start with the
same row count ("3x3"/"3x4"/"3x5"), so parsing the count back out of the
text wouldn't be unambiguous. Node name stays the stable identifier; label
text is purely for display and gets overwritten from `BoardLayout.label_for()`
in code regardless of whatever placeholder text the `.tscn` shows in the
editor.

**Selected-option highlight:** each card-count button has an explicit
`theme_override_styles/pressed` (and `hover_pressed`) `StyleBoxFlat` — a
warm gold fill with a brown border — set directly in `parent_settings.tscn`,
rather than relying on the engine's default (too-subtle) pressed style.
This is scoped to just these three buttons via per-node style overrides,
not a global project `Theme` change, since so far they're the only toggle
buttons in the game; if more radio-style settings show up later, consider
promoting this into `assets/theme/game_theme.tres` as `Button.styles.pressed`
instead of copy-pasting the override onto every new button.

### Worked example: enabled categories (`WordDatabase.get_all_categories()`)

The parent can also turn whole word categories on/off (e.g. hide "colors"
if it's confusing rather than helpful) — at least
`WordDatabase.MIN_ENABLED_CATEGORIES` (2) have to stay on, so the board
never runs out of distinct words. Two things had to be centralized for
this to stay low-maintenance as more categories get added later:

- **Which categories exist at all.** `WordDatabase.get_all_categories()`
  derives this from `WORDS`' image paths (`assets/images/<category>/...`)
  rather than a separate hand-maintained list — a word's category was
  already implied by which folder its icon lives in, so a second list
  would just be one more thing to keep in sync (and forget to). Adding a
  category is exactly what `docs/asset-pipeline.md` already says for
  adding a word, plus one `CATEGORY_<NAME>` row in `localization/ui.csv`
  (see Localization below) — nothing else.
- **The minimum-2 rule.** `WordDatabase.MIN_ENABLED_CATEGORIES` is the one
  place that number lives; both `ParentSettings` (to decide when to lock
  the checkboxes) and `Main` (to decide whether a stored value is still
  valid) read it from there rather than each hand-coding `2`.

`ParentSettings._setup_category_list()` builds one `CheckBox` per category
**in code**, not as hand-authored `.tscn` nodes (unlike the fixed 3-button
card-count row) — since the whole point is that this list grows on its own
as categories are added, a fixed set of scene nodes would need editing
every time, defeating that. Each checkbox's *node name* is set to the
category name and read back on toggle (same reasoning as the card-count
buttons using node name over label text, see above) — its displayed text
is `tr("CATEGORY_%s" % category.to_upper())`, so an added category with no
corresponding `localization/ui.csv` row just shows its raw key
(`"CATEGORY_DINOSAURS"`) as a visible reminder to add one, rather than
failing silently.

**Enforcing "at least 2" is a UI lock, not a rejected action.**
`_update_category_lock_state()` runs after every toggle: once exactly
`MIN_ENABLED_CATEGORIES` boxes are checked, *those specific checked boxes*
get `disabled = true` (so they can't be unchecked further) while any
still-unchecked ones stay tappable (checking one more re-enables
everything, since the lock check only re-runs against the current count).
This was chosen over silently reverting a disallowed uncheck because it's
discoverable — the parent can see which boxes are locked and infer why,
rather than tapping a box and watching nothing happen. `Main` re-validates
independently in `_apply_stored_enabled_categories()` (filters out
categories that no longer exist, falls back to no filter at all if fewer
than `MIN_ENABLED_CATEGORIES` survive that) rather than trusting the UI's
enforcement blindly — same "stored data could be stale or hand-edited"
posture as the card-count setting.

**Known limitation, not solved here:** categories vary a lot in size right
now (`nature` has 4 words, `food` has 5, others have 10) — enabling just
two small categories can leave fewer words available than a large card
count asks for. `WordDatabase.get_random_words()` already clamps to
whatever's actually available rather than erroring, so the board just
comes up smaller than requested; there's no cross-validation between the
card-count and categories settings to prevent that combination. Worth
revisiting if it turns out to matter in practice.

Persistence here is explicitly best-effort, not mission-critical: any
load/save failure (missing file on first run, a corrupt file, a web/HTML5
`user://` quirk) is logged via `push_warning` and swallowed rather than
crashing; callers just get their supplied default back. Godot 4's HTML5
export backs `user://` with IndexedDB and syncs it automatically in most
cases — this was spot-checked manually (export, set a value, reload the
page) rather than guarded against in code, consistent with "not
mission-critical."

## Visuals: project-wide font and text color

Parent mode is the first screen in the game with any visible text, which
surfaced two things the engine's built-in default theme doesn't give you:
readable-by-default text color, and a font that fits a toddler app rather
than a generic UI default. Both are fixed via one project-wide `Theme`
resource, `assets/theme/game_theme.tres`, registered as the engine's default
UI theme in `project.godot`'s `[gui]` section
(`theme/custom="res://assets/theme/game_theme.tres"`) — so this isn't
parent-mode-specific, it applies to any `Control` anywhere in the project
that doesn't set its own override, including future toddler-facing text if
any gets added later.

- **Text color:** the engine's built-in default theme's text color reads as
  light/white, which was unreadable against this project's cream/tan
  backgrounds (`Color(0.996, 0.973, 0.906, 1)`, used both for the main
  background and the gate/settings panels). The theme sets a dark warm-brown
  `Label`/`Button` `font_color` (`Color(0.28, 0.18, 0.11, 1)`) instead,
  matching the existing icon border/shadow brown tones (see
  `word_card.tscn`'s `StyleBoxFlat_ring`/`StyleBoxFlat_shadow`). `ParentGate`'s
  `ErrorLabel` intentionally overrides this locally to red — that's the one
  deliberate departure, everything else should inherit the theme default
  rather than setting its own color.
- **Font:** `assets/fonts/SuperWarming-Regular.ttf`, a bold rounded/bubbly
  typeface that fits the toddler-app tone much better than the engine
  default. **Picking it required checking actual glyph coverage, not just
  vibes:** the first, more overtly "cartoonish" candidates tried —Fredoka,
  Fredoka One, Chewy — all turned out to be **missing `ő`/`ű`**, the
  Hungarian double-acute characters, which would have silently broken
  existing vocabulary (`WORD_CLOUD` "felhő", `WORD_SHOE` "cipő",
  `WORD_FIRE_TRUCK` "tűzoltóautó") and even this feature's own
  `PARENT_GATE_TITLE` ("Szülői mód"); a later "Matcha Mint" candidate was
  worse still — ASCII-only, missing *every* accented Hungarian letter, not
  just `ő`/`ű`. Both were caught the same way: dump the font's cmap with
  `fontTools` and diff it against the actual character set used in
  `localization/words.csv`/`ui.csv`, not the font's advertised subset list
  or how it looks rendering English. Super Warming was verified the same
  way before being adopted (zero missing characters against those two
  CSVs). **Any future font swap must redo this check.** Unlike the Baloo 2
  it replaced, Super Warming ships as a single weight/file — both
  `default_font` and `Button`'s font in `game_theme.tres` point at the same
  `SuperWarming-Regular.ttf`, and the gate/settings screens' `TitleLabel`/
  `CodeDisplay` local font overrides (originally there to opt into a
  separate Bold weight) now just point at that same single file too, kept
  as explicit overrides rather than removed so a future per-screen size/
  weight tweak has somewhere to go. No bundled license file came with this
  font (unlike Baloo 2's `Baloo2-OFL.txt`); it was added on the strength of
  the user's own confirmation of its license/source rather than a
  redistributable license text in this repo — worth revisiting if that
  provenance ever needs to be produced (e.g. a store listing review).
- **Checkbox tint is a separate property from text color — easy to miss.**
  The category checklist's checkmarks initially rendered white-on-cream
  (poor contrast) even though `Button/colors/font_color` was already set
  correctly, because `CheckBox` has its own `checkbox_checked_color`/
  `checkbox_unchecked_color` theme colors that tint the check *icon*, wholly
  separate from `font_color` (which only affects the adjacent label text).
  Godot's per-type theme fallback (`CheckBox` → `Button`, since `CheckBox`
  extends `Button`) covers properties both types share, like `font_color`,
  but obviously can't cover `checkbox_checked_color` since plain `Button`
  doesn't have that property at all — there's nothing to fall back to, so
  it fell all the way through to the engine's built-in default (white).
  Fixed by setting `CheckBox/colors/checkbox_checked_color` (and
  `_unchecked_color`, for consistency) explicitly in `game_theme.tres`.
  **Any future control type with its own dedicated theme colors needs the
  same check** — don't assume setting `font_color`/`Button.*` covers
  everything; inspect `ThemeDB.get_default_theme().get_color_list("<Type>")`
  for the actual type before trusting inheritance to carry a color over.

## Localization

Parent-mode UI copy lives in `localization/ui.csv` → `ui.hu.translation`
(registered in `project.godot`'s `[internationalization]` alongside
`words.hu.translation` — `TranslationServer` merges every registered
`.translation` resource into one lookup, and the `PARENT_*`/`WORD_*`/
`PRAISE_*` key namespaces don't collide). Kept separate from `words.csv`
because that file is tightly 1:1 coupled to `WordDatabase.WORDS` (each row
implies an icon + per-locale audio asset); parent-mode strings are UI chrome
with no audio asset, and mixing them in would make that coupling
inaccurate.

Two ways translated text reaches these screens, both used here:
- **Static, scene-authored text** (titles, instructions, button labels):
  the `.tscn` sets the `Label`/`Button` `text` property directly to the
  English/neutral key (e.g. `text = "PARENT_GATE_TITLE"`). Godot's
  `Control` nodes auto-translate their text-like properties against the
  registered `Translation` resources by default — no script code needed.
- **Dynamic, script-composed text** (the countdown, which interpolates a
  number): call `tr("KEY")` explicitly in the script, e.g.
  `tr("PARENT_GATE_COUNTDOWN") % seconds_left`.

This is the project's first real localized-text call site — until now, all
user-facing content was audio/image-driven per CLAUDE.md's localization
architecture. The parent gate is an intentional, narrow exception to the
"no reading required" design constraint for the toddler audience: it's only
reachable via a deliberate 5-tap adult gesture, not part of the toddler-facing
game loop.

## Testing

Mirrors `docs/testing.md`'s three-tier pattern, under `test/parent/`:
- **Pure logic:** `tap_gesture_detector_test.gd` drives
  `TapGestureDetector.register_tap(explicit_ms)` directly (no real waits) to
  cover the reset-window and re-trigger behavior; `parent_gate_test.gd`
  checks `_generate_code()` always returns a `CODE_LENGTH`-digit numeric
  string.
- **Single scene:** `parent_gate_test.gd` (continued) and
  `parent_settings_test.gd` instantiate the real `.tscn`, override
  `deadline_seconds` to a tiny value before calling `start()`, and drive
  button `pressed` signals directly — covering correct entry, wrong-entry
  retry, deadline expiry, and settings' close signal.
  `settings_test.gd`, `parent_settings_test.gd`, and
  `main_settings_integration_test.gd` all redirect `Settings` to a scratch
  file via `before()`/`after()` (see "Local settings storage" above) rather
  than trusting `persist: false` alone. `parent_settings_test.gd` also
  covers the card-count row (labels show the RxC shape not the bare count,
  correct button pressed for a stored/missing value, tapping one saves it)
  and the category checklist (one checkbox per category, reflects a stored
  subset, toggling saves it, that unchecking down to the minimum locks the
  remaining checked boxes and checking a third one unlocks them again, and
  — its own extra-isolated test, redirecting to a second, guaranteed
  never-yet-created file rather than the suite's shared scratch file — that
  a *genuinely* fresh install, not just "reset to the default value", has
  every category enabled) — each of the state-mutating tests still restores
  `SettingsKeys.CARD_COUNT`/`SettingsKeys.ENABLED_CATEGORIES` to their
  defaults afterward, since the suite's scratch file is shared across every
  test *within* that file for its whole run. `board_layout_test.gd` is pure
  logic (no scene at all) for `columns_for`/`label_for`, including their
  unknown-count fallbacks; `word_database_test.gd` similarly covers
  `get_all_categories()` and `get_random_words()`'s category filter
  (including that an empty/omitted `categories` param still means "no
  filter", preserving every pre-existing call site's behavior).
- **`main_settings_integration_test.gd`:** the other half of both settings
  — that `Main` actually *reads* stored values (card count, deriving the
  matching grid `columns`; enabled categories, filtering `displayed_words`)
  on startup, not just that `ParentSettings` can write them. Sets
  `Settings` directly, then creates its own `scene_runner` per test (rather
  than a shared `before_test()`) since the value has to already be in
  place before `Main._ready()` runs.
- **Integration:** one minimal `scene_runner` test drives
  `TapGestureDetector.register_tap()` directly on the real `%Background`
  node inside the real `main.tscn`, five times, and asserts a `ParentGate`
  appears with `get_tree().paused == true`. **Known blind spot:** this
  deliberately does *not* simulate a real positioned mouse/touch click —
  gdUnit4 v6.2.0's `simulate_mouse_button_pressed()` didn't reliably route
  through Control hit-testing in this headless setup the way real input
  does, so a first attempt at that came back green-looking-but-wrong (it
  actually failed outright, which is what prompted the switch to calling
  `register_tap()` directly). The practical effect: **this test cannot
  catch a `mouse_filter`/layout regression that stops a real tap from ever
  reaching `Background`** — exactly the kind of bug the `Layout`/`Center`
  `mouse_filter` wiring above is about, and exactly the kind of bug this
  suite in fact missed once already. Whether a real screen tap reaches
  `Background` has to be checked by hand in the running game (editor or a
  build) after any layout change near `Background`/`Layout`/`Center`/
  `CardGrid` — don't trust this test alone for that. Also not covered:
  typing a full code through the real UI via `scene_runner` (cheaper at the
  single-scene tier already) and the `reload_current_scene()` exit path (a
  single documented Godot API call, not worth the flakiness/cost of
  exercising through the runner) — same reasoning `docs/testing.md` already
  applies to `reroll_board()`/`retry_delay`.

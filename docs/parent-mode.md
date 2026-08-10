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
audience (toddlers) can't reliably read a 4-digit number or operate a
keypad. Wrong entries clear and let the parent retry the *same* code; only a
manual cancel or the deadline expiring closes it.

The 30-second deadline is driven by a `create_tween().tween_method(...)`
animating a countdown value from `deadline_seconds` to `0`, rather than a
`Timer` node (none exist elsewhere in this codebase) or a bare
`await get_tree().create_timer(...).timeout`. One mechanism gets three
things for free: a live countdown bar/label, trivial cancel-on-success
(`tween.kill()`), and a natural expiry signal (`tween.finished`).

`deadline_seconds` is deliberately **not** consumed in `_ready()` — it's
read when `start()` is called, which `ParentModeCoordinator` calls right
after `add_child()`. This split exists so a test can set a tiny
`deadline_seconds` before `start()` runs, instead of eating a real 30-second
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
backed by `ConfigFile` at `user://settings.cfg`:

```gdscript
Settings.get_value("some_key", default_value)
Settings.set_value("some_key", new_value)   # writes to disk immediately
```

**To add a real setting once the settings screen needs one:** add a control
under `%ContentContainer` in `scenes/parent/parent_settings.tscn`, and wire
it directly to `Settings.get_value`/`set_value`. No other code changes are
needed — this mirrors `word_database.gd`'s own "no other code changes
needed" pattern for adding a word.

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
- **Font:** `assets/fonts/Baloo2-{Regular,Bold}.ttf` (Google Fonts, SIL Open
  Font License — `assets/fonts/Baloo2-OFL.txt`), a bold rounded/bubbly
  typeface that fits the toddler-app tone much better than the engine
  default. **Picking it required checking actual glyph coverage, not just
  vibes:** the first, more overtly "cartoonish" candidates tried —Fredoka,
  Fredoka One, Chewy — all turned out to be **missing `ő`/`ű`**, the
  Hungarian double-acute characters, which would have silently broken
  existing vocabulary (`WORD_CLOUD` "felhő", `WORD_SHOE` "cipő",
  `WORD_FIRE_TRUCK` "tűzoltóautó") and even this feature's own
  `PARENT_GATE_TITLE` ("Szülői mód"). Baloo 2 was verified to have full
  `latin-ext` coverage (checked programmatically against
  `WordDatabase`/`ui.csv`'s actual character set, not just the font's
  advertised subset list) before being adopted. **Any future font swap must
  redo this check** — a font that looks right for English/vibes-based
  browsing can still be silently broken for this project's actual (Hungarian)
  content. `default_font` (Regular) covers `Label`s generally; `Button`
  gets the Bold weight project-wide for a chunkier, more obviously-tappable
  look, and the gate/settings screens' `TitleLabel`/`CodeDisplay` opt into
  Bold locally for header emphasis.

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
  checks `_generate_code()` always returns a 4-digit numeric string.
- **Single scene:** `parent_gate_test.gd` (continued) and
  `parent_settings_test.gd` instantiate the real `.tscn`, override
  `deadline_seconds` to a tiny value before calling `start()`, and drive
  button `pressed` signals directly — covering correct entry, wrong-entry
  retry, deadline expiry, and settings' close signal.
  `settings_test.gd` exercises the real `Settings` autoload (default
  fallback, round-trip) using `persist: false` so tests don't write to a
  developer's real `user://settings.cfg`.
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

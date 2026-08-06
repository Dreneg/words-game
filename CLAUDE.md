# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project overview

A 2D Android game built in Godot Engine, aimed at small children who are just
learning to speak. The core gameplay loop: the game speaks/shows a word, and
the child taps the image on screen that matches it. Simple, forgiving,
touch-first — no reading required, no fail states that punish wrong taps hard.

- **Engine:** Godot 4.7
- **Language:** GDScript
- **Renderer:** GL Compatibility (`renderer/rendering_method = gl_compatibility`)
  — chosen for broad Android device support, keep it that way unless there's
  a specific reason to switch to Forward+/Mobile.
- **Target platform:** Android (touch input, portrait or landscape — confirm
  orientation before building UI that assumes one).
- **Primary content language:** Hungarian. The game must be built so
  additional languages can be added later without code changes (see
  Localization below).

## Code and content language rules

- **All code, identifiers, comments, scene names, and filenames are in
  English.** No Hungarian in the codebase itself.
- **In-game user-facing content** (spoken words, on-screen labels, prompts)
  is Hungarian today, but must be pulled through the localization system —
  never hardcode Hungarian (or any) strings directly in scripts or scenes.

## Localization architecture

Use Godot's built-in translation system so new languages are just new data,
not code changes:

- Text: CSV or gettext (`.po`/`.pot`) translation files under a
  `localization/` folder, loaded via `ProjectSettings` and looked up with
  `tr("KEY")`. Keys are English/neutral identifiers (e.g. `WORD_CAT`,
  `PROMPT_FIND_THE`), never the literal Hungarian text.
- Audio (word pronunciation, prompts): since the target audience can't read,
  most content is voice-over driven, not text-driven. Organize audio assets
  per-locale, e.g. `assets/audio/<locale>/<key>.ogg`, keyed by the same
  identifiers used for text, and resolve the active locale at runtime via
  `TranslationServer.get_locale()` (or an explicit in-game language setting —
  don't rely only on device locale for a kids' app).
- Adding a language should mean: add a locale folder of audio + a translation
  file + register the locale — no script changes.
- Default/fallback locale: Hungarian (`hu`).

## Placeholder asset generation

No real voice actor or illustrator is attached to this project yet, so word
audio and images are AI-generated placeholders. Keep every new word
consistent with the existing set by using the same pipeline:

- **Voice:** Microsoft Edge neural TTS via the `edge-tts` Python package
  (`python3 -m pip install --user edge-tts`). Always use voice
  **`hu-HU-NoemiNeural`** (female, "Friendly, Positive") for Hungarian —
  don't mix voices within a locale, or words will sound like they came from
  different speakers. If another locale is added later, pick one neural
  voice for it the same way and record the choice here.
  ```
  python3 -m edge_tts --voice hu-HU-NoemiNeural --text "<hungarian word>" \
	--write-media /tmp/<KEY>.mp3
  ffmpeg -y -i /tmp/<KEY>.mp3 -ar 44100 -ac 1 assets/audio/hu/<KEY>.ogg
  ```
  Output must be mono, 44.1kHz, ogg vorbis, filed at
  `assets/audio/<locale>/<KEY>.ogg` where `<KEY>` matches the
  `localization/words.csv` key exactly. This requires network access
  (cloud TTS, not a local/offline model) — flag it if generating audio in an
  offline environment.
- **Images:** hand-authored flat SVG icons (no photorealistic/AI image
  generation is available in this environment) — bold single-color shapes on
  a soft circular background, consistent with the existing icons under
  `assets/images/<category>/`. Godot imports `.svg` directly as a texture,
  so no rasterization step is needed.
  - Give every icon 1–2 small secondary accents on top of the base shapes —
	an accessory (collar, bow, bell), a texture touch (a couple of scale or
	peel strokes, a leaf vein), or a shading detail (a highlight, a soft
	shadow crescent) — so it doesn't read as bare. Keep accents bold and few:
    no fine/hairline linework, no busy texture, and the base silhouette must
    still read instantly at small size — accents support recognition, they
	don't compete with it.
  - Sanity-check new/edited icons at actual icon scale before committing:
	`magick path/to/icon.svg -resize 200x200 preview.png` (ImageMagick, via
	`convert` if `magick` isn't found), then look at the PNG. Arc/path math
    for crescent or wedge shapes is easy to get visually wrong blind (e.g.
	accents landing off the shape they're meant to sit on) — render and
	check rather than trusting the coordinates on paper. This also catches
	accents that are only readable as intended at large size — e.g. a
	4-circle flower can compress into an unrecognizable "X" at icon scale —
	so judge every accent at the actual render size, not the source coords.
  - Creatures get a full body, not a floating head portrait: a body shape
	plus legs (sitting with visible front paws/legs for pets, standing on
	4 legs with hooves for farm quadrupeds, perching/floating with feet or
	a bill for birds). A silhouette that's just ears + head + face reads as
	unfinished next to the rest of the set.
  - Give each word its own silhouette. Two icons built from the same base
	template and only recolored (same body/head/limb shapes, different
	fill) will look like the same animal twice regardless of palette — the
	fix is different anatomy and pose, not a different color. If two icons
	in a category end up structurally interchangeable, redesign one's pose
	and defining features (e.g. a perching bird with a pointed beak and a
	twig vs. a floating duck with a flat bill and no visible legs) rather
	than just swapping hues.
  - Watch z-order when shapes overlap, especially at a neck/waist seam
	between a head and a body: draw the piece that should read as "behind"
	first and the piece that should read as "in front" last. A wider shape
	painted after a narrower one can visually swallow it even when both
	use the same fill color (e.g. a body ellipse erasing a head's jawline)
	— this only shows up in the render, not in the coordinates, so check.
  - Don't use an axis-aligned rect to fill a space with a sloped edge (e.g.
	a car window against an angled roofline) — corners will poke past the
	outline into the background. Use a path shaped to the boundary instead.
  - Before calling a category done, render the whole set together at icon
	scale in one contact sheet (montage/tile the PNGs), not just each icon
	individually — that's what actually surfaces two icons reading as too
	similar, or one icon looking out of place next to its siblings.
- After adding files, run `godot --headless --path . --import` (or open the
  editor once) so Godot generates `.import` files and the `.translation`
  resource, and confirm the new key is registered under
  `[internationalization]` in `project.godot`. This can have the side effect
  of rewriting unrelated fields in `project.godot` from stale editor cache
  (seen: `config/name` silently reset to an old value) — diff `project.godot`
  after importing and revert anything unrelated to the asset change.
- These are placeholders: treat both voice and art as swappable for
  professional recordings/illustrations before a real release.

## Design constraints (target audience: toddlers learning to speak)

- Large, forgiving touch targets. No fine-motor precision required.
- No text-reading requirement — everything communicated through images,
  color, and audio/voice.
- Positive reinforcement on wrong answers rather than harsh failure states.
- Keep screens uncluttered — a small number of clear image choices at a time.

## Project structure (establish as content is added)

Keep a conventional Godot layout; create folders as needed rather than
dumping everything at the root:

- `scenes/` — `.tscn` scenes, PascalCase or feature-based subfolders.
- `scripts/` — `.gd` scripts, `snake_case.gd` filenames, matching
  `class_name` in PascalCase when a script defines a reusable class.
- `assets/images/` — game art, organized by category/word set.
- `assets/audio/<locale>/` — per-language voice-over and SFX.
- `localization/` — translation CSV/PO files.

## GDScript conventions

- `snake_case` for variables, functions, and file names.
- `PascalCase` for class names, node names, and `class_name` declarations.
- Prefer typed GDScript (`var x: int`, typed function signatures) for
  clarity and editor tooling.
- Use signals for decoupled UI/game-logic communication (e.g. an image
  button emitting a signal on tap rather than the game logic reaching into
  UI nodes directly).

## Testing / running

This is a Godot project — verify changes by opening/running the project in
the Godot editor (or `godot --path .` from the project root) rather than
assuming correctness from reading code alone. When testing Android-specific
behavior (touch input, screen sizes), note that in your summary since it
can't be fully verified from the editor alone.

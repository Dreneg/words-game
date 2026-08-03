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
  a soft circular background, no fine detail, consistent with the existing
  icons under `assets/images/<category>/`. Godot imports `.svg` directly as
  a texture, so no rasterization step is needed.
- After adding files, run `godot --headless --path . --import` (or open the
  editor once) so Godot generates `.import` files and the `.translation`
  resource, and confirm the new key is registered under
  `[internationalization]` in `project.godot`.
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

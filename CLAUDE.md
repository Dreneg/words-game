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
audio and images are AI-generated placeholders, kept consistent with the
existing set via a fixed pipeline (voice: `edge-tts` with a single pinned
Hungarian voice; images: hand-authored flat SVG icons with a documented
detail/consistency checklist). Full pipeline, commands, and icon-design
lessons learned:

@docs/asset-pipeline.md

## Design constraints (target audience: toddlers learning to speak)

- Large, forgiving touch targets. No fine-motor precision required.
- No text-reading requirement — everything communicated through images,
  color, and audio/voice.
- Positive reinforcement on wrong answers rather than harsh failure states.
- Keep screens uncluttered — a small number of clear image choices at a time.
- Exception: **parent mode** (see below) deliberately requires reading a
  4-digit number — that's intentional, since it's only reachable via a
  5-tap adult gesture, not part of the toddler-facing game loop.

## Parent mode

A gesture-gated settings area, hidden from the toddler player: 5 taps on the
background opens a code challenge, and the correct code opens a settings
screen. Settings persist locally (works in both the Android and web
builds) via a generic `Settings` autoload, so new settings controls can be
added later without touching the gesture/gate/storage plumbing. Full
architecture — the gesture detector, the countdown/retry mechanism, the
pause-then-restart lifecycle, and the storage API:

@docs/parent-mode.md

## Project structure (establish as content is added)

Keep a conventional Godot layout; create folders as needed rather than
dumping everything at the root:

- `scenes/` — `.tscn` scenes, PascalCase or feature-based subfolders (e.g.
  `scenes/parent/` for the parent-mode gate/settings screens).
- `scripts/` — `.gd` scripts, `snake_case.gd` filenames, matching
  `class_name` in PascalCase when a script defines a reusable class (e.g.
  `scripts/parent/` for parent-mode scripts; autoloads stay at the
  `scripts/` root alongside `word_database.gd`/`settings.gd`).
- `assets/images/` — game art, organized by category/word set.
- `assets/audio/<locale>/` — per-language voice-over and SFX.
- `assets/fonts/`, `assets/theme/` — the project-wide UI font/`Theme`
  resource (see @docs/parent-mode.md's "Visuals" section — any font swap
  must be re-checked for full Hungarian glyph coverage, not just English).
- `localization/` — translation CSV/PO files (`words.csv` for playable
  vocabulary, coupled 1:1 to icons/audio; separate CSVs like `ui.csv` for
  UI chrome text that has no audio asset).
- `docs/` — longer reference docs pulled into this file via `@docs/*.md`
  imports (keep this file itself short and scannable; put anything long
  and self-contained here instead of growing a section in place).

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

### Automated tests (GdUnit4)

Tests live under `test/`, named `<subject>_test.gd`, using
[GdUnit4](https://github.com/MikeSchulze/gdUnit4) vendored at
`addons/gdUnit4`. Full guide — test patterns (pure logic / single scene /
full scene_runner integration), version-specific `scene_runner` gotchas,
and the headless CLI invocation:

@docs/testing.md

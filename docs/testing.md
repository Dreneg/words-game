# Automated tests (GdUnit4)

Tests live under `test/`, named `<subject>_test.gd`, using
[GdUnit4](https://github.com/MikeSchulze/gdUnit4) vendored at
`addons/gdUnit4` (v6.2.0, chosen for its stated Godot 4.7 support — check
`addons/gdUnit4/README.md`'s version badges before upgrading). A test suite
extends `GdUnitTestSuite` and asserts with `assert_that(...)`. Autoloads
(e.g. `WordDatabase`) are available in tests exactly as in the running game,
since the test runner boots the full project. `main.gd` has a `class_name
Main` (matching `WordCard`'s own `class_name`) purely so tests can hold a
statically-typed reference to it — this project otherwise has one scene per
script and wouldn't normally need one.

Three patterns, by what they touch:

- **Pure logic, no scene tree** (`test/word_database_test.gd`,
  `test/main_test.gd`): instantiate the script directly with `.new()` (must
  be typed, e.g. `var main: Main = auto_free(Main.new())` — `auto_free()`
  returns `Variant`, and this project treats the resulting untyped-inference
  warning as a hard error) and call methods/set fields directly. Runs
  instantly.
- **A single scene in isolation** (`test/word_card_test.gd`): instantiate
  the `.tscn` (not just the script) and `add_child(...)` it so `_ready()`
  actually runs and resolves its `%UniqueName` references, then interact
  with it directly. Runs instantly.
- **The full game loop through the real scene** (`test/main_integration_test.gd`):
  `GdUnitSceneRunner` (`scene_runner("res://scenes/main.tscn")`) boots the
  actual `main.tscn`. Two gotchas that don't match the framework's own
  docs/tutorials floating around online, both true as of v6.2.0:
  - There is no `await_idle_frame()` on this version's runner; use
    `await runner.await_input_processed()` instead.
  - `GdUnitSceneRunner` is `RefCounted`, not a `Node` — don't call
    `runner.free()` in `after_test()` (errors: "Attempted to free a
    RefCounted object"). Just drop the reference (`runner = null`); its
    `NOTIFICATION_PREDELETE` handler tears down the instantiated scene.

  These tests wait out `main.gd`'s real `delay_before_prompt` timer in real
  time — `scene_runner` shares the same `SceneTree` that
  `get_tree().create_timer()` schedules against, so there's no fast-forward
  without changing production code — costing ~2s (wall clock) each; keep
  the number of full-round tests here small. **Intentionally not covered**
  for the same reason: `reroll_board()` (the animated board-swap after
  `correct_answers_per_reroll` correct answers) and the `retry_delay`
  re-prompt loop — both are tween/timer-heavy, slow to exercise for real,
  and lower-risk than the core prompt/tap/advance loop that is covered.

Run the whole suite headlessly from the project root:

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://test -c --ignoreHeadlessMode
```

(`-a` adds the directory/file to run, `-c` runs the full set instead of
stopping at the first failure, `--ignoreHeadlessMode` is required — this
GdUnit4 version refuses to run in `--headless` mode without it, since
`InputEvent`-driven UI tests, e.g. via `scene_runner`, don't work headless.
Pure-logic tests like the ones here are unaffected.) This writes an
`.xml`/`.html` report under `reports/` (gitignored) — safe to delete after
reading. Note: some third-party docs/tutorials for GdUnit4 reference an
older `--run-tests` CLI flag; that flag doesn't exist in v6.2.0, use `-a`
as above.

From the editor: open the GdUnit4 panel (bottom dock) and click "Run All".

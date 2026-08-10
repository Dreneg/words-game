extends GdUnitTestSuite
## Minimal integration test for parent-mode entry: driving
## TapGestureDetector.register_tap() -- the same entry point a real tap's
## gui_input calls -- on the real Background node inside the real running
## main.tscn confirms ParentModeCoordinator's wiring end to end (gesture ->
## paused tree -> ParentGate appears), without depending on gdUnit4's
## position-based mouse simulation actually routing through Control
## hit-testing. main_integration_test.gd's own tests avoid relying on that
## too (they tap WordCard buttons directly rather than simulating a
## screen-position click). Whether a real screen tap reaches Background at
## all is a scene-wiring concern -- the mouse_filter changes documented in
## docs/parent-mode.md -- verified manually per that doc rather than
## re-proven here.
##
## Deliberately not covered here either: typing a full code through the
## real UI (cheaper at the single-scene tier already, see
## parent_gate_test.gd) and the reload_current_scene() exit path (a single
## documented Godot API call, not worth the flakiness/cost of exercising
## through the runner) -- same reasoning main_integration_test.gd applies
## to its own exclusions.

var runner: GdUnitSceneRunner


func before_test() -> void:
	runner = scene_runner("res://scenes/main.tscn")


func after_test() -> void:
	get_tree().paused = false # defensive: don't leak a paused tree into the next test
	# GdUnitSceneRunner is RefCounted, not a Node -- it can't be .free()'d
	# manually. Dropping the reference triggers its own NOTIFICATION_PREDELETE
	# cleanup (removes and frees the instantiated scene) immediately.
	runner = null


func test_five_taps_opens_parent_gate_and_pauses_the_tree() -> void:
	await runner.await_input_processed()
	var main := runner.scene() as Main
	var background := main.find_child("Background", true, false) as TapGestureDetector

	for i in background.required_taps:
		background.register_tap(i * 100) # well within tap_reset_window

	assert_that(get_tree().paused).is_true()
	var gate := main.find_child("ParentGate", true, false)
	assert_that(gate).is_not_null()

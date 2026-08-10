extends GdUnitTestSuite
## Tests for TapGestureDetector (scripts/parent/tap_gesture_detector.gd):
## pure tap-counting/reset-window logic, driven with explicit timestamps via
## register_tap() so it runs instantly without waiting out tap_reset_window
## for real.


func test_required_taps_within_window_emits_gate_requested() -> void:
	var detector: TapGestureDetector = auto_free(TapGestureDetector.new())
	monitor_signals(detector)

	for i in detector.required_taps:
		detector.register_tap(i * 100) # 100ms apart, well within the window

	await assert_signal(detector).is_emitted("gate_requested")


func test_gap_past_reset_window_restarts_the_count() -> void:
	var detector: TapGestureDetector = auto_free(TapGestureDetector.new())
	monitor_signals(detector)

	var window_ms := int(detector.tap_reset_window * 1000.0)
	detector.register_tap(0)
	detector.register_tap(100)
	# Gap far longer than tap_reset_window: counting restarts from 1 here,
	# so only 3 of the required 5 taps land in-window afterward.
	detector.register_tap(100 + window_ms + 500)
	detector.register_tap(200 + window_ms + 500)
	detector.register_tap(300 + window_ms + 500)

	await assert_signal(detector).wait_until(50).is_not_emitted("gate_requested")


func test_fires_again_after_a_previous_trigger() -> void:
	var detector: TapGestureDetector = auto_free(TapGestureDetector.new())
	for i in detector.required_taps:
		detector.register_tap(i * 100)

	monitor_signals(detector) # only monitor the second sequence
	for i in detector.required_taps:
		detector.register_tap(10000 + i * 100)

	await assert_signal(detector).is_emitted("gate_requested")

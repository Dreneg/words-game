extends GdUnitTestSuite
## Tests for ParentGate (scripts/parent/parent_gate.gd): the code-challenge
## screen. deadline_seconds is overridden to a tiny value before start() so
## nothing here waits out a real 30-second window -- start() (rather than
## _ready()) is exactly what makes that possible, see docs/parent-mode.md.

const ParentGateScene := preload("res://scenes/parent/parent_gate.tscn")


func test_generate_code_is_always_four_digits() -> void:
	var gate: ParentGate = auto_free(ParentGate.new())
	for i in 50: # pure randomness: run enough times to catch an off-by-one
		var code: String = gate._generate_code()
		assert_that(code.length()).is_equal(4)
		assert_that(code.is_valid_int()).is_true()


func test_correct_code_emits_unlocked() -> void:
	var gate := _start_gate()
	monitor_signals(gate)

	_enter_code(gate, gate._expected_code)

	await assert_signal(gate).is_emitted("unlocked")


func test_wrong_code_clears_and_allows_retry_with_same_code() -> void:
	var gate := _start_gate()
	var correct_code: String = gate._expected_code
	var wrong_code := _different_code(correct_code)
	monitor_signals(gate)

	_enter_code(gate, wrong_code)
	await assert_signal(gate).wait_until(50).is_not_emitted("unlocked")
	assert_that(gate.entered_digits_label.text).is_equal("○ ○ ○ ○")
	assert_that(gate.error_label.visible).is_true()

	# The code doesn't change on a miss -- retrying with the original code
	# must still succeed.
	_enter_code(gate, correct_code)
	await assert_signal(gate).is_emitted("unlocked")


func test_deadline_expiry_with_no_entry_emits_cancelled() -> void:
	var gate := _start_gate(0.05)
	monitor_signals(gate)

	await assert_signal(gate).is_emitted("cancelled")


func test_success_cancels_the_pending_deadline() -> void:
	var gate := _start_gate(0.05)
	monitor_signals(gate)

	_enter_code(gate, gate._expected_code)
	await assert_signal(gate).is_emitted("unlocked")

	# Past where the tiny deadline would have fired: confirm success killed
	# the countdown tween rather than leaving it to fire cancelled too.
	await assert_signal(gate).wait_until(200).is_not_emitted("cancelled")


func _start_gate(deadline_seconds: float = 30.0) -> ParentGate:
	var gate := auto_free(ParentGateScene.instantiate()) as ParentGate
	add_child(gate)
	gate.deadline_seconds = deadline_seconds
	gate.start()
	return gate


func _enter_code(gate: ParentGate, code: String) -> void:
	for digit_char in code:
		_press_digit(gate, digit_char.to_int())


func _press_digit(gate: ParentGate, digit: int) -> void:
	for child in gate.keypad.get_children():
		var button := child as Button
		if button and button.text == str(digit):
			button.pressed.emit()
			return


func _different_code(code: String) -> String:
	var first_digit := (code.substr(0, 1).to_int() + 1) % 10
	return str(first_digit) + code.substr(1)

class_name ParentGate
extends Control
## The "prove you're an adult" screen: shows a random 4-digit code and asks
## the parent to type it back on an on-screen keypad within
## [member deadline_seconds]. This isn't a secret password -- it's shown
## right on screen -- it only works as a gate because the target audience
## (toddlers) can't read digits or operate a keypad accurately yet.
##
## Instantiated and owned by [ParentModeCoordinator], which listens for
## [signal unlocked] (correct code) and [signal cancelled] (manual cancel or
## deadline expiry) to decide what happens next. See docs/parent-mode.md.

signal unlocked()
signal cancelled()

## Fixed deadline from the moment [method start] is called, in seconds.
## Deliberately not read until [method start] (not [method _ready]) so a
## test can override it to a tiny value first -- see docs/parent-mode.md.
@export var deadline_seconds: float = 30.0

@onready var code_display_label: Label = %CodeDisplay
@onready var countdown_bar: ProgressBar = %CountdownBar
@onready var countdown_label: Label = %CountdownLabel
@onready var entered_digits_label: Label = %EnteredDigits
@onready var error_label: Label = %ErrorLabel
@onready var keypad: GridContainer = %Keypad
@onready var backspace_button: Button = %BackspaceButton
@onready var cancel_button: Button = %CancelButton

var _expected_code: String = ""
var _entered_digits: String = ""
var _deadline_tween: Tween


func _ready() -> void:
	for child in keypad.get_children():
		var button := child as Button
		if button and button.text.is_valid_int():
			button.pressed.connect(_on_digit_pressed.bind(int(button.text)))
	backspace_button.pressed.connect(_on_backspace_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	error_label.visible = false


## Generates a fresh code and starts the countdown. Called by
## [ParentModeCoordinator] right after this scene is added to the tree.
func start() -> void:
	_expected_code = _generate_code()
	_entered_digits = ""
	code_display_label.text = _expected_code
	_update_digits_display()
	error_label.visible = false

	countdown_bar.max_value = deadline_seconds
	_deadline_tween = create_tween()
	_deadline_tween.tween_method(_update_countdown, deadline_seconds, 0.0, deadline_seconds)
	_deadline_tween.finished.connect(_on_deadline_expired)


func _generate_code() -> String:
	return "%04d" % randi_range(0, 9999)


func _update_countdown(seconds_left: float) -> void:
	countdown_bar.value = seconds_left
	countdown_label.text = tr("PARENT_GATE_COUNTDOWN") % int(ceil(seconds_left))


func _on_deadline_expired() -> void:
	cancelled.emit()


func _on_digit_pressed(digit: int) -> void:
	if _entered_digits.length() >= 4:
		return
	_entered_digits += str(digit)
	_update_digits_display()
	if _entered_digits.length() == 4:
		_check_code()


func _on_backspace_pressed() -> void:
	if _entered_digits.is_empty():
		return
	_entered_digits = _entered_digits.substr(0, _entered_digits.length() - 1)
	_update_digits_display()


func _on_cancel_pressed() -> void:
	_deadline_tween.kill()
	cancelled.emit()


func _check_code() -> void:
	if _entered_digits == _expected_code:
		_deadline_tween.kill()
		unlocked.emit()
	else:
		_entered_digits = ""
		_update_digits_display()
		_show_error()


func _update_digits_display() -> void:
	var filled := _entered_digits.length()
	var slots: Array[String] = []
	for i in 4:
		slots.append("●" if i < filled else "○")
	entered_digits_label.text = " ".join(slots)


## Brief flash to signal a wrong code without kicking the parent back to the
## main screen -- matches [method WordCard.play_correct_feedback]'s
## fade/flash idiom.
func _show_error() -> void:
	error_label.modulate.a = 1.0
	error_label.visible = true
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(error_label, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func() -> void: error_label.visible = false)

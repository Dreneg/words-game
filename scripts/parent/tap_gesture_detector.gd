class_name TapGestureDetector
extends ColorRect
## Attached directly to `Background` in `scenes/main.tscn`. Counts taps that
## land anywhere on the background (i.e. not on a card) and, once
## [member required_taps] land within [member tap_reset_window] of each
## other, emits [signal gate_requested] to open the parent gate.
##
## This is deliberately the only gesture-handling code in the game -- see
## docs/parent-mode.md for why [member Control.mouse_filter] has to change
## on both this node and its `Layout` sibling for taps to ever reach here.

signal gate_requested()

## How many taps trigger the gate.
@export var required_taps: int = 5
## Max gap between consecutive taps before the count resets to 1. Long
## enough for a deliberate adult tap sequence, short enough that a
## toddler's incidental screen contact over a play session won't add up.
@export var tap_reset_window: float = 1.5

var _tap_count: int = 0
var _last_tap_msec: int = 0


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		register_tap(Time.get_ticks_msec())


## Pure counting logic, separated from the real input event so it can be
## unit-tested with explicit timestamps instead of real waits.
func register_tap(now_msec: int) -> void:
	if _tap_count > 0 and now_msec - _last_tap_msec > tap_reset_window * 1000.0:
		_tap_count = 0
	_tap_count += 1
	_last_tap_msec = now_msec
	if _tap_count >= required_taps:
		_tap_count = 0
		gate_requested.emit()

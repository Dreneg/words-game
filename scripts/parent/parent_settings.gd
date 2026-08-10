class_name ParentSettings
extends Control
## The parent settings screen, reached only after [ParentGate] accepts the
## code. Future settings controls go under [member content_container] and
## read/write their values via the [autoload Settings] store directly, using
## a shared key from [SettingsKeys] -- see docs/parent-mode.md for the full
## add-a-setting recipe (writing the value here is only half of it; whatever
## gameplay code the setting actually affects has to read it back too, e.g.
## [method Main._apply_stored_card_count]).

signal closed()

@onready var content_container: VBoxContainer = %ContentContainer
@onready var close_button: Button = %CloseButton
@onready var card_count_row: HBoxContainer = %CardCountRow


func _ready() -> void:
	close_button.pressed.connect(func() -> void: closed.emit())
	_setup_card_count_row()


## Labels each card-count button with its actual "RxC" board shape (see
## [BoardLayout]) instead of a bare card count, marks whichever one matches
## the currently-stored value (or [constant BoardLayout.DEFAULT_COUNT] if
## none was ever saved) as pressed -- which, combined with each button's
## StyleBoxFlat "pressed" override in the scene, is what visibly highlights
## the current selection -- and wires each button to save its value on tap.
## Each button's node name (e.g. "CardCount9") is its value, read directly
## rather than duplicated in a parallel array, so the buttons stay the
## single source of truth (same idiom [ParentGate] uses for its keypad,
## which reads each button's displayed digit instead).
func _setup_card_count_row() -> void:
	var current: int = Settings.get_value(SettingsKeys.CARD_COUNT, BoardLayout.DEFAULT_COUNT)
	for child in card_count_row.get_children():
		var button := child as Button
		if button == null:
			continue
		var value := button.name.trim_prefix("CardCount").to_int()
		button.text = BoardLayout.label_for(value)
		button.button_pressed = value == current
		button.pressed.connect(_on_card_count_pressed.bind(value))


func _on_card_count_pressed(value: int) -> void:
	Settings.set_value(SettingsKeys.CARD_COUNT, value)

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
@onready var category_list: VBoxContainer = %CategoryList


func _ready() -> void:
	close_button.pressed.connect(func() -> void: closed.emit())
	_setup_card_count_row()
	_setup_category_list()


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


## Builds one CheckBox per [method WordDatabase.get_all_categories] entry
## into [member category_list] -- built here rather than hand-authored in
## the scene so a new category (a new assets/images/<category>/ folder,
## per docs/parent-mode.md) gets a checkbox automatically, no scene edits
## needed. Each checkbox's node name is set to the category name (read back
## on toggle), and its label is [code]tr("CATEGORY_<NAME>")[/code] -- an
## untranslated category shows its raw key as a reminder to add that row to
## localization/ui.csv.
func _setup_category_list() -> void:
	var all_categories := WordDatabase.get_all_categories()
	var enabled := _load_enabled_categories(all_categories)
	for category in all_categories:
		var checkbox := CheckBox.new()
		checkbox.name = category
		checkbox.text = tr("CATEGORY_%s" % category.to_upper())
		checkbox.button_pressed = enabled.has(category)
		checkbox.toggled.connect(_on_category_toggled)
		category_list.add_child(checkbox)
	_update_category_lock_state()


## Same validation [method Main._apply_stored_enabled_categories] does
## (filter to categories that still exist, re-check the minimum), kept
## separate since this screen and Main read the same stored value through
## two different code paths that can't share a call without one depending
## on the other's node lifecycle.
func _load_enabled_categories(all_categories: Array[String]) -> Array[String]:
	var stored: Variant = Settings.get_value(SettingsKeys.ENABLED_CATEGORIES, all_categories)
	var valid: Array[String] = []
	if stored is Array:
		for entry: Variant in stored:
			if entry is String and all_categories.has(entry):
				valid.append(entry)
	return valid if valid.size() >= WordDatabase.MIN_ENABLED_CATEGORIES else all_categories


func _on_category_toggled(_pressed: bool) -> void:
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, _currently_enabled_categories())
	_update_category_lock_state()


func _currently_enabled_categories() -> Array[String]:
	var enabled: Array[String] = []
	for child in category_list.get_children():
		var checkbox := child as CheckBox
		if checkbox and checkbox.button_pressed:
			enabled.append(String(checkbox.name))
	return enabled


## Once only [constant WordDatabase.MIN_ENABLED_CATEGORIES] remain checked,
## disables those specific checkboxes so the parent can't drop below the
## minimum -- still-unchecked categories stay freely toggleable (checking
## one more re-enables everything, since it's only the *checked* ones that
## get locked). See docs/parent-mode.md.
func _update_category_lock_state() -> void:
	var enabled_count := _currently_enabled_categories().size()
	var lock := enabled_count <= WordDatabase.MIN_ENABLED_CATEGORIES
	for child in category_list.get_children():
		var checkbox := child as CheckBox
		if checkbox:
			checkbox.disabled = lock and checkbox.button_pressed

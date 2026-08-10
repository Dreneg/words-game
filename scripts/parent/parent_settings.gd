class_name ParentSettings
extends Control
## The parent settings screen, reached only after [ParentGate] accepts the
## code. Empty today -- future settings controls go under [member content_container]
## and read/write their values via the [autoload Settings] store directly;
## no other code changes are needed to add one. See docs/parent-mode.md.

signal closed()

@onready var content_container: VBoxContainer = %ContentContainer
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(func() -> void: closed.emit())

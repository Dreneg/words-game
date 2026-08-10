class_name ParentModeCoordinator
extends Node
## Wires the 5-tap gesture on [member background] to opening [ParentGate],
## the gate's success to opening [ParentSettings], and either screen's exit
## back to the running game. Added as a plain (non-visual) child of `Main`
## in `scenes/main.tscn`.
##
## Exiting parent mode -- whether the gate was cancelled/timed out, or
## settings were closed -- fully restarts the game via
## [method SceneTree.reload_current_scene] rather than trying to resume the
## interrupted round in place. This is simpler and more robust than
## reasoning about exactly what state survived the pause, and it's the
## natural point to pick up any newly-saved settings anyway. See
## docs/parent-mode.md.

const ParentGateScene := preload("res://scenes/parent/parent_gate.tscn")
const ParentSettingsScene := preload("res://scenes/parent/parent_settings.tscn")

@onready var background: TapGestureDetector = %Background
@onready var word_audio_player: AudioStreamPlayer = %WordAudioPlayer
@onready var praise_audio_player: AudioStreamPlayer = %PraiseAudioPlayer

var _active_overlay: Control = null


func _ready() -> void:
	background.gate_requested.connect(_open_gate)


func _open_gate() -> void:
	word_audio_player.stop()
	praise_audio_player.stop()
	get_tree().paused = true

	var gate := ParentGateScene.instantiate() as ParentGate
	add_child(gate)
	_active_overlay = gate
	gate.unlocked.connect(_on_unlocked)
	gate.cancelled.connect(_close_and_restart)
	gate.start()


func _on_unlocked() -> void:
	_active_overlay.queue_free()

	var settings := ParentSettingsScene.instantiate() as ParentSettings
	add_child(settings)
	_active_overlay = settings
	settings.closed.connect(_close_and_restart)


func _close_and_restart() -> void:
	_active_overlay.queue_free()
	_active_overlay = null
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

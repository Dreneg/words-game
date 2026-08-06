class_name WordCard
extends Control
## A single tappable icon in the matching grid.
##
## Main assigns this card a word via [method setup]; the card only knows how
## to display its icon, report taps, and play its own correct-match
## animation. It has no opinion on whether the tap was right — Main decides
## that and calls [method play_correct_feedback] when it was.
##
## Layered as Shadow (behind) -> Icon (the actual button/texture) -> Ring
## (in front). The border ring and drop shadow are drawn entirely in
## word_card.tscn via StyleBoxFlat -- no source .svg is touched -- so every
## icon gets clear separation from the page background even when an icon's
## own pastel backing is close in color to it.

signal selected(word_key: String)

@onready var icon_button: TextureButton = %Icon

var word_key: String = ""
## Forwards to the inner button so Main can keep addressing the card
## directly (card.disabled = ...) without knowing about the Icon/Ring/Shadow
## layering underneath.
var disabled: bool = false:
	set(value):
		disabled = value
		if icon_button:
			icon_button.disabled = value


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	icon_button.pressed.connect(func() -> void: selected.emit(word_key))
	icon_button.disabled = disabled


## Assigns this card's word key and icon texture. Call right after
## instantiating, before adding to the scene tree is fine too.
func setup(key: String, image_path: String) -> void:
	word_key = key
	icon_button.texture_normal = load(image_path)


## Bounces the whole card (shadow, icon and ring together) and flashes it
## green to celebrate a correct match. Leaves the card disabled afterwards --
## Main replaces the board shortly after, so it doesn't need to be
## re-enabled.
func play_correct_feedback() -> void:
	disabled = true

	var bounce := create_tween()
	bounce.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(self, "scale", Vector2(1.25, 1.25), 0.18)
	bounce.tween_property(self, "scale", Vector2.ONE, 0.18)

	var flash := create_tween()
	flash.tween_property(self, "modulate", Color(0.6, 1.0, 0.65), 0.15)
	flash.tween_property(self, "modulate", Color.WHITE, 0.35)

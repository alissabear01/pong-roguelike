extends CanvasLayer
## Full-screen banner + fade that sits on top of everything.
## Autoloaded as `Transition`, and set to process while the tree is paused so
## the animation still plays when gameplay is frozen between levels.

## how long the banner sits on screen before the fade starts
@export var banner_hold: float = 0.9

## seconds for the banner to pop in
@export var banner_pop_time: float = 0.12

## how far (in pixels) the banner slides up as it pops in
@export var banner_pop_rise: float = 6.0

## seconds for the screen to go fully dark, and the same again coming back
@export var fade_time: float = 0.45

@onready var fade: ColorRect = $Fade
@onready var banner: Label = $Banner


func _ready() -> void:
	# start clear: no dimming, no text
	fade.color.a = 0.0
	banner.text = ""
	banner.modulate.a = 0.0


## Pops the banner in, holds it, then leaves it on screen for fade_out to clear.
func show_banner(text: String) -> void:
	banner.text = text
	_set_banner_drop(banner_pop_rise)

	var tween := create_tween().set_parallel()
	# starts overbright and settles to normal, so it reads as a flash
	banner.modulate = Color(2.0, 2.0, 2.0, 0.0)
	tween.tween_property(banner, "modulate", Color.WHITE, banner_pop_time)
	tween.tween_method(_set_banner_drop, banner_pop_rise, 0.0, banner_pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	# create_timer keeps ticking while the tree is paused
	await get_tree().create_timer(banner_hold).timeout


## Darkens the screen to solid, taking any visible banner with it.
func fade_out() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(fade, "color:a", 1.0, fade_time)
	tween.tween_property(banner, "modulate:a", 0.0, fade_time)
	await tween.finished
	banner.text = ""


## Brings the new scene back in from solid.
func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_time)
	await tween.finished


# The banner is anchored to the whole screen, so shifting both vertical offsets
# by the same amount slides it without fighting the anchors. Rounding keeps the
# pixel font landing on whole pixels instead of blurring across two.
func _set_banner_drop(dy: float) -> void:
	var snapped := roundf(dy)
	banner.offset_top = snapped
	banner.offset_bottom = snapped

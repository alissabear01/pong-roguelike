extends StaticBody2D
## A chest with a ball trapped inside. Fades in when the level spawns it.
## Hitting it flashes it white, squashes it and pops it open in a burst of
## bits and gold sparkles, and the level sends a new ball flying out of it.

## fires when the chest breaks, with where the new ball should come out
signal ball_released(at: Vector2)

## the burst of chest bits when it breaks
@export var break_effect: PackedScene
## gold sparkle burst that goes off with the bits, so it feels like a reward
@export var sparkle_effect: PackedScene = preload("res://scenes/effects/chest_sparkles.tscn")
## seconds the fade in on spawn takes
@export var fade_in_time: float = 0.4

## how bright the chest flashes when it's hit (1 = normal, higher = whiter)
@export var flash_strength: float = 3.0

## seconds for the squash, the pop up and the vanish, in that order
@export var squash_time: float = 0.06
@export var pop_time: float = 0.08
@export var vanish_time: float = 0.2

@onready var sprite: Sprite2D = $Sprite2D

var opened := false


func _ready() -> void:
	# the ball's aim assist steers at chests too, and the level checks this
	# group to know whether a chest is already out
	add_to_group("upgrade_chests")

	# grow in from small and see-through
	sprite.modulate.a = 0.0
	sprite.scale = Vector2(0.5, 0.5)
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "modulate:a", 1.0, fade_in_time)
	tween.tween_property(sprite, "scale", Vector2.ONE, fade_in_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## called by the ball. always breaks the chest, so returns true and the ball
## flies on through
func take_damage(_amount: int = 1) -> bool:
	if opened:
		return false

	opened = true
	remove_from_group("upgrade_chests")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	ball_released.emit(global_position)
	Sfx.play(&"chest_open")

	# flash white and squash flat like the ball smacked it...
	sprite.modulate = Color(flash_strength, flash_strength, flash_strength)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.45, 0.65), squash_time)
	# ...then spring up tall as the flash fades
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.35), pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, pop_time)
	# bits and sparkles fly right as it pops
	tween.tween_callback(_burst)
	tween.tween_property(sprite, "scale", Vector2(1.6, 0.2), vanish_time)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, vanish_time)
	tween.tween_callback(queue_free)
	return true


# the effects go on the level, not the chest, so they outlive it
func _burst() -> void:
	for effect: PackedScene in [break_effect, sparkle_effect]:
		if effect == null:
			continue
		var fx: Node2D = effect.instantiate()
		get_parent().add_child(fx)
		fx.global_position = global_position

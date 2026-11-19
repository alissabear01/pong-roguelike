extends StaticBody2D
## A chest with a ball trapped inside. Fades in when the level spawns it.
## Hitting it bursts it into bits, fades it out, and the level sends a new
## ball flying out of it in a random direction.

## fires when the chest breaks, with where the new ball should come out
signal ball_released(at: Vector2)

## the burst of chest bits when it breaks
@export var break_effect: PackedScene
## seconds the fade in on spawn takes
@export var fade_in_time: float = 0.4
## seconds the fade out on breaking takes
@export var fade_out_time: float = 0.3

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

	if break_effect:
		var fx := break_effect.instantiate()
		# add to the level, not to us, since we're about to go
		get_parent().add_child(fx)
		fx.global_position = global_position

	# quick squash, then swell up a little while fading away
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.7), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), fade_out_time)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, fade_out_time)
	tween.tween_callback(queue_free)
	return true

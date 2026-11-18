extends StaticBody2D

signal upgrade_revealed(upgrade: StringName)

const UPGRADES: Array[StringName] = [&"speed", &"size", &"power"]

@onready var sprite: Sprite2D = $Sprite2D

var opened := false


func _ready() -> void:
	add_to_group("upgrade_chests")


func take_damage(_amount: int = 1) -> void:
	if opened:
		return

	opened = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	upgrade_revealed.emit(UPGRADES.pick_random())

	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.45, 0.65), 0.08)
	tween.tween_property(sprite, "scale", Vector2(0.25, 1.5), 0.1)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

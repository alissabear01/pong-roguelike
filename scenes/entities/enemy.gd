extends StaticBody2D
# breakable (killable!) enemy. takes dmg when the ball hits it and dies at 0 health

## how many hits this enemy survives. set per-instance in the inspector
@export var max_health: int = 1

var health: int

func _ready() -> void:
	health = max_health
	# group lets the level count how many enemies are left
	add_to_group("enemies")

@onready var sprite:Sprite2D = $Sprite2D

## called by ball when it collides with this enemy
func take_damage(amount: int = 1) -> void:
	health -= amount
	print("hit, health now: ",health)
	if health <= 0:
		die()
	else: 
		shake()
	
func shake() -> void:
	var start:= sprite.position
	var tween:= create_tween()
	# flash white on hit
	sprite.modulate = Color(3, 3, 3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	# jitter a little when hit! then settle back to og position
	for i in 4:
		tween.tween_property(sprite, "position",
			start+ Vector2(randf_range(-1,1), randf_range(-1,1)), 0.015)
	tween.tween_property(sprite, "position", start, 0.015)

func die() -> void:
	# queue_free() removes the node safely at the end of the frame
	queue_free()

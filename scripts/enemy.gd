extends StaticBody2D
# breakable (killable!) enemy. takes dmg when the ball hits it and dies at 0 health

## fires the moment health hits 0, so the level can count down what's left
signal died

## how many hits this enemy survives. set per-instance in the inspector
@export var max_health: int = 1

var health: int

## the area this enemy's whole body has to stay inside while it moves. the
## level sets it before adding the enemy. left empty, the enemy stands still
var move_bounds: Rect2

## where the enemy was placed. any moving it does is around this spot
var home: Vector2

func _ready() -> void:
	health = max_health
	home = position
	# group lets the level count how many enemies are left
	add_to_group("enemies")

## true if the whole body would be inside move_bounds with its centre at pos
func _fits_at(pos: Vector2) -> bool:
	if not move_bounds.has_area():
		return false
	var body := _body_rect()
	body.position += pos
	return move_bounds.encloses(body)

## box around every collision shape (the skeleton's shield too), relative to
## our position. mirrored left/right so it holds whichever way we face
func _body_rect() -> Rect2:
	var rect := Rect2()
	for shape: CollisionShape2D in find_children("*", "CollisionShape2D", true, false):
		var r := shape.shape.get_rect()
		r.position += to_local(shape.global_position)
		var mirrored := Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)
		rect = r.merge(mirrored) if not rect.has_area() else rect.merge(r).merge(mirrored)
	return rect

@onready var sprite:Sprite2D = $Sprite2D

## called by ball when it collides with this enemy
func take_damage(amount: int = 1) -> void:
	health -= amount
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

@export var death_effect: PackedScene

func die() -> void:
	died.emit()
	if death_effect:
		var fx:= death_effect.instantiate()
		# add to the level, not to self - about to self destruct......
		get_parent().add_child(fx)
		fx.global_position= global_position
	# queue_free() removes the node safely at the end of the frame
	queue_free()

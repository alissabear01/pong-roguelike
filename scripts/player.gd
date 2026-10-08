class_name Player
extends CharacterBody2D

@export var speed := 200.0

## half the paddle size, used by the ball to work out where along the paddle it hit
@onready var half_width: float = $CollisionShape2D.shape.size.x / 2
@onready var half_height: float = $CollisionShape2D.shape.size.y / 2


func _ready() -> void:
	# lets the ball find us, so it can spot when we've slid over the top of it
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	# Walls are on physics layer 1 (our collision_mask), so move_and_slide stops us at them
	move_and_slide()

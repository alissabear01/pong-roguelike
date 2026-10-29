class_name Player
extends CharacterBody2D

@export var speed := 200.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

## half the paddle width, used by the ball to work out where along the paddle it hit
var half_width: float


func _ready() -> void:
	# copy the shape first! the .tscn shares one shape resource, so editing it
	# directly would also change the paddle saved in the scene file
	collision.shape = collision.shape.duplicate()
	collision.shape.size.x *= RunState.paddle_width_mult
	sprite.scale.x = RunState.paddle_width_mult
	half_width = collision.shape.size.x / 2


func _physics_process(_delta: float) -> void:
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	# Walls are on physics layer 1 (our collision_mask), so move_and_slide stops us at them
	move_and_slide()

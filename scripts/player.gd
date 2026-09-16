extends CharacterBody2D

@export var speed := 600.0

@onready var half_width: float = $CollisionShape2D.shape.size.x / 2


func _physics_process(_delta: float) -> void:
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()
	position.x = clampf(position.x, half_width, get_viewport_rect().size.x - half_width)

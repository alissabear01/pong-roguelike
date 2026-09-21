extends CharacterBody2D
## The ball, moves at a constant speed & reflects off any surface it hits
## uses CharacterBody2D rather than RigidBody2D so we control the exact velocity vector

## ball speed in pixels per s, can tweak in inspector
@export var speed: float = 300.0

# runs when ball enters the scene
func _ready() -> void:
	# picks random launch angle between 45 & 135 degrees so ball goes downwardish & adds velocity -- can change later
	var angle := randf_range(PI * 0.25, PI * 0.75)
	velocity = Vector2.RIGHT.rotated(angle) * speed

# runs 60x per s on physics clock. movement is here
func _physics_process(delta: float) -> void:
	# try to move. if hit something, return collision info null if not. delta converts px per s to px this frame
	var collision := move_and_collide(velocity * delta)
	if collision:
		# get_normal() is direction the suface faces. bounce() reflects our velocity off it
		velocity = velocity.bounce(collision.get_normal())
		
		# if it was something breakable, damage it
		var hit = collision.get_collider()
		if hit.has_method("take_damage"):
			hit.take_damage()

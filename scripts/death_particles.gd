extends GPUParticles2D

func _ready() -> void:
	emitting = true
	# Delete self once the burst finishes.
	finished.connect(queue_free)

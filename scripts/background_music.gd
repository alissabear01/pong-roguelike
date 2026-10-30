extends AudioStreamPlayer

## Looping is set in the WAV's import settings (Loop Mode: Forward). Setting
## loop_mode here instead leaves loop_end at 0 and the track plays silence.


func _ready() -> void:
	if not playing:
		play()

extends CanvasLayer
## always-on-screen run info. autoloaded as 'HUD', so every level gets it for free

@onready var lives_label: Label = $Lives/LivesLabel

func _ready() -> void:
	RunState.lives_changed.connect(_on_lives_changed)
	#draw once now, since RunState already emitted before we were listening
	_on_lives_changed(RunState.lives)

func _on_lives_changed(lives: int) -> void:
	lives_label.text = "x%d" % lives

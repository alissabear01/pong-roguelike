extends CanvasLayer
## "Pick 1 of 3" screen shown between levels. Autoloaded as `UpgradePicker`.
## Process mode is Always, so it works while the game is paused (same trick as Transition).

## fires when a button is clicked, carrying the chosen upgrade's id
signal picked(id: String)

@onready var buttons: Array[Button] = [
	$Layout/Choices/Choice1,
	$Layout/Choices/Choice2,
	$Layout/Choices/Choice3,
]

# the 3 upgrades currently on offer, in button order
var _options: Array = []


func _ready() -> void:
	hide()
	for i in buttons.size():
		# bind(i) tells the callback which button was pressed
		buttons[i].pressed.connect(_on_choice_pressed.bind(i))


## shows 3 random upgrades, waits for a click, then returns the chosen id
func choose() -> String:
	_options = RunState.UPGRADES.duplicate()
	_options.shuffle()
	for i in buttons.size():
		buttons[i].text = "%s\n%s" % [_options[i].name, _options[i].desc]

	show()
	# focus the first button so arrow keys + enter work without a mouse
	buttons[0].grab_focus()
	var id: String = await picked
	hide()
	return id


func _on_choice_pressed(i: int) -> void:
	picked.emit(_options[i].id)

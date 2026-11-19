extends Node
## Plays one-shot sound effects from anywhere: Sfx.play(&"ball_hit").
## Autoloaded as `Sfx`. Keeps a small pool of players so sounds can overlap.
## Runs while the tree is paused, so a sound that starts just before a pause
## (losing the last life, clearing a level) still plays out.
## Sounds: assets/audio/sfx, CC0, see CREDITS.txt there.

const SOUNDS := {
	&"ball_hit": preload("res://assets/audio/sfx/ball_hit.wav"),
	&"enemy_hurt": preload("res://assets/audio/sfx/enemy_hurt.wav"),
	&"enemy_defeated": preload("res://assets/audio/sfx/enemy_defeated.wav"),
	&"life_lost": preload("res://assets/audio/sfx/life_lost.wav"),
	&"aim_beep": preload("res://assets/audio/sfx/aim_beep.wav"),
	&"chest_open": preload("res://assets/audio/sfx/chest_open.wav"),
	&"boss_hurt": preload("res://assets/audio/sfx/boss_hurt.wav"),
	&"boss_defeated": preload("res://assets/audio/sfx/boss_defeated.wav"),
}

## volume tweaks per sound in dB, for any that come out too loud or quiet
const VOLUME := {
	&"ball_hit": -8.0,
	&"aim_beep": -6.0,
}

## how many sounds can play at once. the oldest gets cut off past this
const VOICES := 12

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## pitch above 1 is higher. a little pitch_jitter (like 0.05) stops a sound
## that repeats a lot, like the ball hitting walls, from sounding robotic
func play(sound: StringName, pitch: float = 1.0, pitch_jitter: float = 0.0) -> void:
	if not SOUNDS.has(sound):
		push_warning("no sound called %s" % sound)
		return
	# a free player if there is one, otherwise cut off the oldest
	var player := _players[_next]
	for p in _players:
		if not p.playing:
			player = p
			break
	_next = (_players.find(player) + 1) % VOICES

	player.stream = SOUNDS[sound]
	player.volume_db = VOLUME.get(sound, 0.0)
	player.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	player.play()

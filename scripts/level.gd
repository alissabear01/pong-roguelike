extends Node2D
## Goes on the root of every level. Counts the enemies the level was built with
## and tells LevelManager once the last one is dead.

var _enemies_left: int = 0


func _ready() -> void:
	LevelManager.register_level(scene_file_path)

	# children run _ready before we do, so they're already in the "enemies" group
	for node in find_children("*", "", true, false):
		if node.is_in_group("enemies"):
			_enemies_left += 1
			node.died.connect(_on_enemy_died)

	if _enemies_left == 0:
		push_warning("%s has no enemies, so it can never be cleared" % name)


func _on_enemy_died() -> void:
	_enemies_left -= 1
	if _enemies_left <= 0:
		LevelManager.level_cleared()

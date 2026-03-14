extends GoblinState

## Wander randomly

var _roam_timer := 0.0
var _roam_dir := Vector2.ZERO


func enter() -> void:
	super()
	_pick_roam_direction()


func physics_update(delta: float) -> void:
	_roam_timer -= delta
	if _roam_timer <= 0:
		_pick_roam_direction()

	goblin.movement_component.move(goblin, _roam_dir)
	goblin.visual.play_anim("walk")
	goblin.update_flip(_roam_dir)

	# Check for targets
	var player := PlayerRef.instance
	if player and not player.is_knocked:
		var dist := goblin.global_position.distance_to(player.global_position)
		if dist < goblin.player_detect_range:
			transition.emit("chase")
			return

	var tile := goblin.find_nearest_stealable()
	if tile:
		goblin.target_tile = tile
		transition.emit("approach")


func _pick_roam_direction() -> void:
	_roam_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_roam_timer = goblin.roam_change_interval

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
	var player_in_aggro := false
	
	if player and not player.is_knocked:
		var dist := goblin.global_position.distance_to(player.global_position)
		if dist < 70.0:
			player_in_aggro = true
			transition.emit("chase")
			return
		elif dist < goblin.player_detect_range:
			player_in_aggro = true # we will prioritize player if there's no crop, but if there's a crop we might still go for it later
	
	# Only find crops if player is not strictly in our face
	if not player_in_aggro or randf() > 0.5: # 50% chance to still prefer crops if player is just "nearby" but not "in face"
		var tile := goblin.find_nearest_stealable()
		if tile:
			goblin.target_tile = tile
			transition.emit("approach")
			return
			
	if player_in_aggro:
		transition.emit("chase")


func _pick_roam_direction() -> void:
	_roam_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_roam_timer = goblin.roam_change_interval

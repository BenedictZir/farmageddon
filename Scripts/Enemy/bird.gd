extends EnemyBase
class_name Bird

## An enemy that ignores the player, flies towards a random planted crop, 
## eats it, and flies away. It is invincible while flying and has 1 HP.

var target_tile: Node2D = null
var is_eating := false


func _ready() -> void:
	super()
	
	
	# Find a crop target right as we spawn
	_find_target_crop()
	if target_tile:
		fsm.change_state("FlyIn")
	else:
		# No crops at all? Just fly away immediately
		fsm.change_state("FlyOut")

func _find_target_crop() -> void:
	target_tile = null
	var tiles := get_tree().get_nodes_in_group("plantable_tiles")
	var valid_targets: Array[Node2D] = []
	for tile in tiles:
		if tile is Node2D and tile.has_method("has_planted_crop") and tile.has_planted_crop():
			valid_targets.append(tile)
	
	if valid_targets.size() > 0:
		target_tile = valid_targets.pick_random()


func retarget_crop() -> bool:
	_find_target_crop()
	return target_tile != null

## Override: Birds die instantly and drop nothing
func _on_death() -> void:
	health_bar.value = 0
	if interact_bar: interact_bar.hide()
	fsm.current_state.transition.emit("FlyOut")
	
func _physics_process(delta: float) -> void: # overide, dont stop process when dead because we want to play bird flee anim
	fsm.process_physics(delta)

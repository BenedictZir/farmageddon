extends EnemyBase

## An enemy that ignores the player, flies towards a random planted crop, 
## eats it, and flies away. It is invincible while flying and has 1 HP.

var target_tile: Node2D = null
var is_eating := false

@onready var state_machine: FiniteStateMachine = $StateMachine

func _ready() -> void:
	super()
	
	# Pass self to FSM and initialize
	state_machine.init(self)
	
	# Find a crop target right as we spawn
	_find_target_crop()
	if target_tile:
		state_machine.change_state("FlyIn")
	else:
		# No crops at all? Just fly away immediately
		state_machine.change_state("FlyOut")

func _find_target_crop() -> void:
	var tiles = get_tree().get_nodes_in_group("plantable_tiles")
	var valid_targets = []
	for tile in tiles:
		if tile.placed_crop != null:
			valid_targets.append(tile)
	
	if valid_targets.size() > 0:
		target_tile = valid_targets.pick_random()


func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)


func _process(delta: float) -> void:
	state_machine.process_frame(delta)


## Override: Birds die instantly and drop nothing
func _on_death() -> void:
	if health_bar: health_bar.hide()
	if interact_bar: interact_bar.hide()
	state_machine.current_state.transition.emit("FlyOut")
	
	

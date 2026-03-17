extends State
class_name BirdEatState

var eat_timer := 0.0
var eat_duration := 3.0

func enter() -> void:
	super()
	eat_timer = 0.0
	entity.is_eating = true
	entity.velocity = Vector2.ZERO
	entity.visual.play_anim("eat")
	
	# Turn ON collision so player can defend the crop
	entity.set_collision_layer_value(3, true) # Layer 3 is generally Enemies
	
func exit() -> void:
	entity.is_eating = false
	entity.set_interact_progress(0, false)
	
func physics_update(delta: float) -> void:
	entity.velocity = Vector2.ZERO
	eat_timer += delta
	
	# Show interact bar visually (Red/Green)
	entity.set_interact_progress(eat_timer / eat_duration, true)
	
	# In plantable_tile, 'placed_crop' is the Crop instance
	if not is_instance_valid(entity.target_tile) or entity.target_tile.placed_crop == null:
		# Player snatched the crop while the entity was eating!
		transition.emit("FlyOut")
		return
		
	if eat_timer >= eat_duration:
		# Successfully ate the crop. We need to destroy it and free up the tile.
		if entity.target_tile.placed_crop != null:
			entity.target_tile.placed_crop.queue_free()
			entity.target_tile.placed_crop = null
			entity.target_tile.occupied = false
		transition.emit("FlyOut")

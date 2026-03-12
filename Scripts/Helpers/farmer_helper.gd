class_name FarmerHelper
extends Helper

## Farmer NPC — automatically finds crops to plant/harvest.
## AI loop: Idle → find work → walk to target → do action → repeat

enum FarmerState {
	IDLE_LOOKING,   # Scanning for work
	MOVING_TO_CROP, # Walking toward a crop
	FARMING,        # Doing/Dig animation (planting or harvesting)
}

var farmer_state := FarmerState.IDLE_LOOKING
var _idle_timer := 0.0

## How long to wait before looking for new work
@export var scan_interval := 1.5


func _ai_process(delta: float) -> void:
	match farmer_state:
		FarmerState.IDLE_LOOKING:
			_idle_timer += delta
			if _idle_timer >= scan_interval:
				_idle_timer = 0.0
				_find_work()
		FarmerState.MOVING_TO_CROP:
			pass  # movement handled by base Helper
		FarmerState.FARMING:
			pass  # animation lock handles this


func _find_work() -> void:
	# TODO: Query the crop/tile system for:
	# 1. Harvestable crops (priority) → walk to it, harvest
	# 2. Empty tilled soil → walk to it, plant
	# For now, just idle
	pass


func _on_arrived_at_target() -> void:
	if farmer_state == FarmerState.MOVING_TO_CROP:
		farmer_state = FarmerState.FARMING
		# TODO: Determine if planting (dig anim) or harvesting (doing anim)
		helper_visual.play_doing()


func _on_anim_finished(state: HelperVisual.AnimState) -> void:
	if state in [HelperVisual.AnimState.DOING, HelperVisual.AnimState.DIG]:
		# Finished farming action, go back to looking for work
		farmer_state = FarmerState.IDLE_LOOKING
		_idle_timer = 0.0


## Called externally to send farmer to a specific crop position
func assign_crop(crop_position: Vector2) -> void:
	farmer_state = FarmerState.MOVING_TO_CROP
	move_to(crop_position)

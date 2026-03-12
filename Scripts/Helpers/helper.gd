class_name Helper
extends CharacterBody2D

## Base class for NPC helpers (Farmer, Warrior).
## Provides shared movement, health, and visual integration.
## Override _ai_process() in subclasses to define behavior.

@onready var movement_component: Node2D = $Components/MovementComponent
@onready var health_component: Node2D = $Components/HealthComponent
@onready var helper_visual: HelperVisual = $HelperVisual

var direction := Vector2.ZERO
var target_position := Vector2.ZERO
var has_target := false

## Minimum distance to consider "arrived" at target
const ARRIVE_THRESHOLD := 4.0


func _ready() -> void:
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.revived.connect(_on_revived)
	helper_visual.animation_state_finished.connect(_on_anim_finished)


func _physics_process(delta: float) -> void:
	if not health_component.is_alive():
		return
	if helper_visual.is_locked():
		velocity = Vector2.ZERO
		return

	_ai_process(delta)

	if has_target:
		direction = (target_position - global_position).normalized()
		var dist := global_position.distance_to(target_position)
		if dist < ARRIVE_THRESHOLD:
			has_target = false
			direction = Vector2.ZERO
			_on_arrived_at_target()
	else:
		direction = Vector2.ZERO

	movement_component.move(self, direction)
	helper_visual.update_movement_anim(direction)


## Override in subclass: called every physics frame for AI logic
func _ai_process(_delta: float) -> void:
	pass


## Override in subclass: called when helper reaches its target position
func _on_arrived_at_target() -> void:
	pass


## Override in subclass: called when a one-shot animation finishes
func _on_anim_finished(_state: HelperVisual.AnimState) -> void:
	pass


func move_to(pos: Vector2) -> void:
	target_position = pos
	has_target = true


func _on_damaged(_amount: float) -> void:
	helper_visual.play_hurt()


func _on_died() -> void:
	velocity = Vector2.ZERO
	direction = Vector2.ZERO
	has_target = false
	helper_visual.play_death()


func _on_revived() -> void:
	helper_visual.play_idle()

extends Node
class_name FiniteStateMachine

## Generic Finite State Machine that manages child State nodes

@export var initial_state: State

var current_state: State
var states := {}


func init(entity: CharacterBody2D) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.fsm = self
			child.entity = entity
			child.transition.connect(_on_child_transition)

	if initial_state:
		initial_state.enter()
		current_state = initial_state


func process_physics(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func process_frame(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func change_state(state_name: String) -> void:
	var new_state: State = states.get(state_name.to_lower())
	if not new_state:
		push_error("FSM: State not found: " + state_name)
		return

	if current_state:
		current_state.exit()

	current_state = new_state
	current_state.enter()


func _on_child_transition(new_state_name: String) -> void:
	change_state(new_state_name)

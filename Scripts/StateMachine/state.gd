extends Node
class_name State

## Base class for states in the Finite State Machine

signal transition(new_state_name: String)

var fsm: FiniteStateMachine
var entity: CharacterBody2D


func _ready() -> void:
	# Hide state logic by default unless overridden
	set_physics_process(false)
	set_process(false)


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func update(_delta: float) -> void:
	pass

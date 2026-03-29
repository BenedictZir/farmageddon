extends Node2D
class_name MovementComponent
@export var movement_speed := 100.0
@export var run_speed := 170.0

var is_running := false

signal started_running
signal stopped_running

func move(character: CharacterBody2D, direction := Vector2.ZERO, running := false) -> void:
	is_running = running and direction != Vector2.ZERO
	var speed := run_speed if is_running else movement_speed
	var target_velocity = direction * speed
	character.velocity = character.velocity.lerp(target_velocity, 0.25)
	character.move_and_slide()

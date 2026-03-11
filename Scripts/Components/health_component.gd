extends Node2D

@export var max_health := 100.0
var current_health := 100.0

signal damaged(amount: float)
signal healed(amount: float)
signal died
signal revived

func _ready():
	current_health = max_health

func take_damage(damage := 0.0) -> void:
	current_health = max(0, current_health - damage)
	damaged.emit(damage)
	if current_health <= 0:
		die()

func heal(heal_amount := 0.0) -> void:
	current_health = min(current_health + heal_amount, max_health)
	healed.emit(heal_amount)

func revive() -> void:
	current_health = max_health
	revived.emit()

func die() -> void:
	died.emit()

func is_alive() -> bool:
	return current_health > 0

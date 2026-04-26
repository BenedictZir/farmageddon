extends Node2D
class_name HealthComponent
@export var max_health := 100.0
var current_health := 100.0
var _died_signaled := false
@export var hit_sfx_volume := -20
signal damaged(amount: float)
signal healed(amount: float)
signal died
signal revived

func _ready():
	current_health = max_health
	_died_signaled = current_health <= 0.0

func take_damage(damage := 0.0, is_from_player := false) -> void:
	if current_health <= 0.0:
		return
	current_health = max(0, current_health - damage)
	damaged.emit(damage)
	if (is_from_player):
		AudioGlobal.start_ui_sfx("res://Assets/SFX/hit.wav", [0.97, 1.02], -5)
	else:
		AudioGlobal.start_ui_sfx("res://Assets/SFX/hit.wav", [0.97, 1.02], hit_sfx_volume)
	if current_health <= 0:
		die()

func heal(heal_amount := 0.0) -> void:
	var was_dead := current_health <= 0.0
	current_health = min(current_health + heal_amount, max_health)
	if was_dead and current_health > 0.0:
		_died_signaled = false
	healed.emit(heal_amount)

func revive() -> void:
	current_health = max_health
	_died_signaled = false
	revived.emit()

func die() -> void:
	if _died_signaled:
		return
	_died_signaled = true
	died.emit()

func is_alive() -> bool:
	return current_health > 0

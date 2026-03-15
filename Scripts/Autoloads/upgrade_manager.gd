extends Node

## Autoload that stores the player's current stat upgrade levels and base values.

signal upgrades_changed

# Current upgrade levels
var health_level := 0
var speed_level := 0
var interact_level := 0

# Configuration
const BASE_HEALTH_PRICE := 30
const BASE_SPEED_PRICE := 40
const BASE_INTERACT_PRICE := 50
const PRICE_MULTIPLIER := 1.5

const HEALTH_BONUS_PER_LEVEL := 20.0
const SPEED_BONUS_PER_LEVEL := 15.0
const INTERACT_BONUS_PER_LEVEL := 0.25 # 25% faster animation


func reset_upgrades() -> void:
	health_level = 0
	speed_level = 0
	interact_level = 0
	upgrades_changed.emit()


func get_health_price() -> int:
	return int(BASE_HEALTH_PRICE * pow(PRICE_MULTIPLIER, health_level))


func get_speed_price() -> int:
	return int(BASE_SPEED_PRICE * pow(PRICE_MULTIPLIER, speed_level))


func get_interact_price() -> int:
	return int(BASE_INTERACT_PRICE * pow(PRICE_MULTIPLIER, interact_level))


func buy_health() -> bool:
	var price = get_health_price()
	if CurrencyManager.spend_gold(price):
		health_level += 1
		_apply_health()
		upgrades_changed.emit()
		return true
	return false


func buy_speed() -> bool:
	var price = get_speed_price()
	if CurrencyManager.spend_gold(price):
		speed_level += 1
		_apply_speed()
		upgrades_changed.emit()
		return true
	return false


func buy_interact() -> bool:
	var price = get_interact_price()
	if CurrencyManager.spend_gold(price):
		interact_level += 1
		upgrades_changed.emit()
		# Interaction speed is read actively by player.gd every interaction
		return true
	return false


func _apply_health() -> void:
	var player = PlayerRef.instance
	if not player:
		return
	var hc = get_tree().get_first_node_in_group("player_health")
	if hc:
		var extra = health_level * HEALTH_BONUS_PER_LEVEL
		hc.max_health = 100.0 + extra
		hc.heal(extra) # Heal for the upgraded amount!


func _apply_speed() -> void:
	var player = PlayerRef.instance
	if not player:
		return
	var mc = player.get("movement_component")
	if mc:
		var extra = speed_level * SPEED_BONUS_PER_LEVEL
		# Note: We'll modify the default movement speed logic remotely later
		# Assuming base speed 100
		mc.speed = 100.0 + extra

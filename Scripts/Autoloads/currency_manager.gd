extends Node

## Currency Manager — Autoload singleton.
## Keeps track of player's gold and emits signal when it changes.

signal gold_changed(new_amount: int)
signal gold_spent(amount: int)

var gold: int = 2000 : set = set_gold

func set_gold(value: int) -> void:
	gold = max(0, value)
	gold_changed.emit(gold)

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	
func spend_gold(amount: int) -> bool:
	if amount <= 0:
		AudioGlobal.start_ui_sfx("res://Assets/SFX/buy_item.wav", [0.97, 1.02], -5)
		return true
	if gold >= amount:
		gold -= amount
		gold_spent.emit(amount)
		AudioGlobal.start_ui_sfx("res://Assets/SFX/buy_item.wav", [0.97, 1.02], -5)
		return true
	return false

func can_afford(amount: int) -> bool:
	return gold >= amount

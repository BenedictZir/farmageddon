extends Node

## Currency Manager — Autoload singleton.
## Keeps track of player's gold and emits signal when it changes.

signal gold_changed(new_amount: int)

var gold: int = 500 : set = set_gold

func set_gold(value: int) -> void:
	gold = max(0, value)
	gold_changed.emit(gold)

func add_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

func can_afford(amount: int) -> bool:
	return gold >= amount

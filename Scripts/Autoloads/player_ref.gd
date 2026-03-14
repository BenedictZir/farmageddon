extends Node

## PlayerRef — Autoload singleton.
## Holds a reference to the current player node. No groups or strings needed.

var instance: CharacterBody2D = null


func register(player: CharacterBody2D) -> void:
	instance = player


func unregister(player: CharacterBody2D) -> void:
	if instance == player:
		instance = null

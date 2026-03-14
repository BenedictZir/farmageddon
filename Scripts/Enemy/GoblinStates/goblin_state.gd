extends State
class_name GoblinState

## Base state for Goblin AI. Provides typed reference to the Goblin entity.

var goblin: GoblinAI


func _ready() -> void:
	super()


func enter() -> void:
	goblin = entity as GoblinAI

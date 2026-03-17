extends State
class_name BirdState

var bird: EnemyBase

func enter() -> void:
	bird = entity as EnemyBase

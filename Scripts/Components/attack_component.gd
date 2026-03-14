class_name AttackComponent
extends Area2D

## Reusable attack hitbox component.
## Activates left or right based on sprite facing direction.

@export var damage := 25.0
@export var offset_distance := 20.0  # how far in front of attacker


func _ready() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	$CollisionShape2D.set_deferred("disabled", true)
	body_entered.connect(_on_body_entered)


## Activate hitbox. is_facing_left = true means attack to the left.
func activate(is_facing_left: bool) -> void:
	position.x = -offset_distance if is_facing_left else offset_distance
	position.y = 0.0
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	await get_tree().create_timer(0.4).timeout
	if monitoring:
		$CollisionShape2D.set_deferred("disabled", false)


## Deactivate hitbox
func deactivate() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	$CollisionShape2D.set_deferred("disabled", true)
	position = Vector2.ZERO


func _on_body_entered(body: Node2D) -> void:
	if body == get_parent():
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_node("Components/HealthComponent"):
		body.get_node("Components/HealthComponent").take_damage(damage)

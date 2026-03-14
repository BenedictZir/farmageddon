extends CharacterBody2D
class_name EnemyBase

## Base class for enemies. Provides shared references and death logic.

@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var attack_component: Area2D = $Components/AttackComponent
@onready var visual: EnemyVisual = $EnemyVisual

## Held item icon (Sprite2D child added by scene or at runtime)
@onready var held_item_sprite: Sprite2D = $HeldItemSprite

var is_dead := false
var interruptible := true


func _ready() -> void:
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	# Create held item sprite if it doesn't exist
	if not has_node("HeldItemSprite"):
		var spr := Sprite2D.new()
		spr.name = "HeldItemSprite"
		spr.visible = false
		spr.z_index = 10
		spr.position = Vector2(5, -12)
		add_child(spr)
		held_item_sprite = spr

func _on_damaged(amount:= 0) -> void:
	if is_dead or not interruptible:
		return
	attack_component.deactivate()
	visual.play_anim_locked("hurt")
func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	_on_death()


## Override in subclasses for custom death behavior
func _on_death() -> void:
	visual.play_anim("death")
	await visual.anim_finished
	queue_free()


func show_held_item(icon: Texture2D) -> void:
	if held_item_sprite:
		held_item_sprite.texture = icon
		held_item_sprite.visible = true


func hide_held_item() -> void:
	if held_item_sprite:
		held_item_sprite.visible = false
		held_item_sprite.texture = null


func update_flip(dir: Vector2) -> void:
	visual.update_flip(dir)
	if held_item_sprite and dir.x != 0:
		held_item_sprite.flip_h = dir.x < 0


func start_jump(duration := 1.0, height := 24.0) -> void:
	# Disable collision mask 1 (World/Fences) so we can jump over them
	set_collision_mask_value(1, false)
	visual.do_jump(duration, height)
	visual.jump_finished.connect(_on_jump_finished, CONNECT_ONE_SHOT)

func _on_jump_finished() -> void:
	# Re-enable collision mask 1
	set_collision_mask_value(1, true)

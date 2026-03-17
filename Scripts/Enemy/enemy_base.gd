extends CharacterBody2D
class_name EnemyBase

## Base class for enemies. Provides shared references and death logic.

@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var attack_component: Area2D = $Components/AttackComponent
@onready var visual: EnemyVisual = $EnemyVisual

@onready var interact_bar: TextureProgressBar = $InteractBar
@onready var health_bar: TextureProgressBar = $EnemyVisual/HealthBar

var held_item_sprite: Sprite2D 

var is_dead := false
var interruptible := true


func _ready() -> void:
	if $HeldItemSprite:
		held_item_sprite = $HeldItemSprite
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	if health_component.has_signal("healed"):
		health_component.healed.connect(_on_healed)
		
	if health_bar:
		health_bar.max_value = health_component.max_health
		health_bar.value = health_component.current_health
	if interact_bar:
		interact_bar.visible = false
		

func _on_damaged(amount:= 0.0) -> void:
	if health_bar:
		health_bar.value = health_component.current_health
	if is_dead or not interruptible:
		return
	attack_component.deactivate()
	visual.play_anim_locked("hurt")
	

func _on_healed(amount:= 0.0) -> void:
	if health_bar:
		health_bar.value = health_component.current_health


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	_on_death()


## Override in subclasses for custom death behavior
func _on_death() -> void:
	if health_bar:
		health_bar.hide()
	if interact_bar:
		interact_bar.hide()
	visual.play_anim("death")
	await visual.anim_finished
	queue_free()


func set_interact_progress(progress: float, is_visible := true) -> void:
	if interact_bar:
		interact_bar.value = progress * 100.0
		interact_bar.visible = is_visible



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

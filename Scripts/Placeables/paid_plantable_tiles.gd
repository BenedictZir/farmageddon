extends Node2D
class_name PaidPlantableTiles

## Group of PlantableTile nodes that must be unlocked with gold.
## Put this node under PlantableTiles, then make PlantableTile nodes children of this patch node.

@export var unlock_price := 15
@export var starts_unlocked := false
@export var interaction_radius := 22.0
@export var proximity_check_interval := 0.1
@export var ui_offset := Vector2(0, -22)
@export var sign_offset := Vector2.ZERO

@export var locked_tint := Color(0.45, 0.45, 0.45, 1.0)
@export var affordable_color := Color(0.55, 1.0, 0.55, 1.0)
@export var unaffordable_color := Color(1.0, 0.45, 0.45, 1.0)
@export var unlock_visual_duration := 0.28
@export var unlock_stagger := 0.03
@export var sign_unlock_duration := 0.22
@export var sign_unlock_drop := 10.0
@export_range(0.01, 1.0, 0.01) var sign_unlock_scale := 0.08

@onready var lock_ui: Node2D = $LockUi
@onready var icon_label: Label = $LockUi/IconLabel
@onready var price_label: Label = $LockUi/PriceLabel
@onready var sign_sprite: Sprite2D = get_node_or_null("SignSprite") as Sprite2D

var _tiles: Array[Node2D] = []
var _is_unlocked := false
var _ui_visible := false
var _ui_tween: Tween
var _sign_tween: Tween
var _proximity_timer := 0.0
var _is_player_near := false


func _ready() -> void:
	_collect_tiles(self)
	_update_ui_anchor()
	icon_label.text = "[LOCKED]"
	price_label.text = "%d G" % unlock_price

	if CurrencyManager.has_signal("gold_changed") and not CurrencyManager.gold_changed.is_connected(_on_gold_changed):
		CurrencyManager.gold_changed.connect(_on_gold_changed)

	_set_unlocked(starts_unlocked)
	_hide_ui_immediate()
	_refresh_price_color()


func _process(_delta: float) -> void:
	if _is_unlocked or GameManager._game_over:
		return

	var player := PlayerRef.instance
	if not player or not player.is_inside_tree():
		_is_player_near = false
		_hide_ui_smooth()
		return

	_proximity_timer -= _delta
	if _proximity_timer <= 0.0:
		_proximity_timer = maxf(0.03, proximity_check_interval)
		_is_player_near = _is_player_near_any_tile(player)
		if _is_player_near:
			_refresh_price_color()

	if _is_player_near:
		_show_ui_smooth()
		if Input.is_action_just_pressed("interact") \
				and GameManager.is_input_unlocked("interact") \
				and _can_consume_interact(player):
			_try_unlock()
	else:
		_hide_ui_smooth()


func _collect_tiles(node: Node) -> void:
	for child in node.get_children():
		if child == lock_ui:
			continue
		if child is Node2D and child.has_method("set_locked"):
			_tiles.append(child)
		if child.get_child_count() > 0:
			_collect_tiles(child)


func _update_ui_anchor() -> void:
	if _tiles.is_empty():
		lock_ui.position = ui_offset
		if sign_sprite:
			sign_sprite.position = sign_offset
		return

	var center := _get_tiles_center_local()
	lock_ui.position = center + ui_offset
	if sign_sprite:
		sign_sprite.position = center + sign_offset


func _get_tiles_center_local() -> Vector2:
	if _tiles.is_empty():
		return Vector2.ZERO

	var center := Vector2.ZERO
	var count := 0
	for t in _tiles:
		if not is_instance_valid(t) or not t.is_inside_tree():
			continue
		center += to_local(t.global_position)
		count += 1

	if count <= 0:
		return Vector2.ZERO

	return center / float(count)


func _set_unlocked(unlocked: bool, smooth_unlock := false) -> void:
	_is_unlocked = unlocked
	set_process(not _is_unlocked)
	for i in range(_tiles.size()):
		var t := _tiles[i]
		if not t.has_method("set_locked"):
			continue

		var visual_duration := unlock_visual_duration if smooth_unlock and unlocked else 0.0
		var delay := (float(i) * unlock_stagger) if smooth_unlock and unlocked else 0.0
		_set_tile_locked_with_delay(t, not unlocked, visual_duration, delay)

	if _is_unlocked:
		_is_player_near = false
		if smooth_unlock:
			_play_sign_unlock_animation()
		else:
			_hide_sign_immediate()
		if smooth_unlock:
			_hide_ui_smooth()
		else:
			_hide_ui_immediate()
	else:
		_show_sign_immediate()


func _try_unlock() -> void:
	if _is_unlocked:
		return
	if not CurrencyManager.spend_gold(unlock_price):
		_bump_ui_error()
		return

	_set_unlocked(true, true)


func _is_player_near_any_tile(player: Node2D) -> bool:
	for t in _tiles:
		if not is_instance_valid(t) or not t.is_inside_tree():
			continue
		if player.global_position.distance_to(t.global_position) <= interaction_radius:
			return true
	return false


func _can_consume_interact(player: Node) -> bool:
	var select_box = player.get("select_box")
	if not select_box:
		return true

	var target = select_box.get("current_target")
	if target == null:
		return true

	return _tiles.has(target)


func _refresh_price_color() -> void:
	if _is_unlocked:
		return
	price_label.self_modulate = affordable_color if CurrencyManager.can_afford(unlock_price) else unaffordable_color


func _show_ui_smooth() -> void:
	if _ui_visible:
		return
	_ui_visible = true
	lock_ui.visible = true
	if _ui_tween and _ui_tween.is_running():
		_ui_tween.kill()

	lock_ui.modulate.a = 0.0
	lock_ui.scale = Vector2(0.85, 0.85)
	_ui_tween = create_tween()
	_ui_tween.tween_property(lock_ui, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ui_tween.parallel().tween_property(lock_ui, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_ui_smooth() -> void:
	if not _ui_visible:
		return
	_ui_visible = false
	if _ui_tween and _ui_tween.is_running():
		_ui_tween.kill()

	_ui_tween = create_tween()
	_ui_tween.tween_property(lock_ui, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ui_tween.parallel().tween_property(lock_ui, "scale", Vector2(0.92, 0.92), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ui_tween.tween_callback(func():
		if not _ui_visible:
			lock_ui.visible = false
	)


func _hide_ui_immediate() -> void:
	_ui_visible = false
	if _ui_tween and _ui_tween.is_running():
		_ui_tween.kill()
	lock_ui.visible = false
	lock_ui.modulate.a = 0.0
	lock_ui.scale = Vector2(0.9, 0.9)


func _show_sign_immediate() -> void:
	if not sign_sprite:
		return
	if _sign_tween and _sign_tween.is_running():
		_sign_tween.kill()
	sign_sprite.visible = true
	sign_sprite.modulate.a = 1.0
	sign_sprite.scale = Vector2.ONE


func _hide_sign_immediate() -> void:
	if not sign_sprite:
		return
	if _sign_tween and _sign_tween.is_running():
		_sign_tween.kill()
	sign_sprite.visible = false
	sign_sprite.modulate.a = 0.0
	sign_sprite.scale = Vector2.ONE


func _play_sign_unlock_animation() -> void:
	if not sign_sprite:
		return
	if _sign_tween and _sign_tween.is_running():
		_sign_tween.kill()

	sign_sprite.visible = true
	sign_sprite.modulate.a = 1.0
	sign_sprite.scale = Vector2.ONE

	var base_pos := sign_sprite.position
	var duration := clampf(sign_unlock_duration, 0.05, 1.0)
	var target_scale := Vector2(sign_unlock_scale, sign_unlock_scale)
	_sign_tween = create_tween()
	_sign_tween.tween_property(sign_sprite, "position:y", base_pos.y + absf(sign_unlock_drop), duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_sign_tween.parallel().tween_property(sign_sprite, "scale", target_scale, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_sign_tween.parallel().tween_property(sign_sprite, "modulate:a", 0.0, duration * 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sign_tween.tween_callback(func():
		sign_sprite.visible = false
	)


func _bump_ui_error() -> void:
	if _ui_tween and _ui_tween.is_running():
		_ui_tween.kill()
	var base_pos := lock_ui.position
	_ui_tween = create_tween()
	_ui_tween.tween_property(lock_ui, "position:x", base_pos.x + 2.0, 0.04)
	_ui_tween.tween_property(lock_ui, "position:x", base_pos.x - 2.0, 0.04)
	_ui_tween.tween_property(lock_ui, "position:x", base_pos.x, 0.04)


func _on_gold_changed(_new_gold: int) -> void:
	if _is_unlocked:
		return
	if _is_player_near:
		_refresh_price_color()


func _set_tile_locked_with_delay(tile: Node2D, locked: bool, smooth_duration: float, delay: float) -> void:
	if delay <= 0.0:
		tile.set_locked(locked, locked_tint, smooth_duration)
		return

	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if is_instance_valid(tile) and tile.has_method("set_locked"):
			tile.set_locked(locked, locked_tint, smooth_duration)
	, CONNECT_ONE_SHOT)

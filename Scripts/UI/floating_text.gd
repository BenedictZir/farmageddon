extends Node2D

@onready var label: Label = $Label

const OVERLAY_LAYER_NAME := "FloatingTextOverlay"
const OVERLAY_LAYER_INDEX := 100

@export var rise_distance := 22.0
@export var anim_duration := 0.5
@export var pop_duration := 0.11
@export var start_scale := Vector2(0.82, 0.82)
@export var final_scale := Vector2.ONE
@export var x_drift_range := 5.0

var _pending_text := "+10"
var _pending_color := Color.GOLD
var _started := false
var _screen_pos := Vector2.ZERO


func setup(text: String, color: Color = Color.GOLD) -> void:
	_pending_text = text
	_pending_color = color
	_apply_pending_style()


func _ready() -> void:
	visible = false

	# Reuse one global overlay layer so each popup does not spawn its own CanvasLayer.
	var overlay := _get_or_create_overlay_layer()
	if overlay and label and label.get_parent() == self:
		remove_child(label)
		overlay.add_child(label)
		label.top_level = true

	_apply_pending_style()
	label.modulate = Color(1, 1, 1, 1)
	label.scale = start_scale

	# Wait one frame so caller can finish assigning global_position after add_child.
	await get_tree().process_frame
	if not is_inside_tree() or not label:
		return

	_screen_pos = (get_global_transform_with_canvas() * Vector2.ZERO).round()
	label.global_position = (_screen_pos - label.size * 0.5).round()
	visible = true
	_start_anim()


func _apply_pending_style() -> void:
	if not label:
		return
	label.text = _pending_text
	label.self_modulate = _pending_color


func _start_anim() -> void:
	if _started:
		return
	_started = true

	var tween = create_tween()
	var drift_x := randf_range(-x_drift_range, x_drift_range)
	var end_pos := label.global_position + Vector2(drift_x, -rise_distance)
	tween.tween_property(label, "scale", final_scale, pop_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Animate directly in screen-space to avoid camera reprojection jitter.
	tween.parallel().tween_property(label, "global_position", end_pos, anim_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Fade out the label
	tween.parallel().tween_property(label, "modulate:a", 0.0, anim_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_cleanup)


func _cleanup() -> void:
	if label and is_instance_valid(label):
		label.queue_free()
	queue_free()


func _exit_tree() -> void:
	if label and is_instance_valid(label) and not label.is_queued_for_deletion() and label.get_parent() != self:
		label.queue_free()


func _get_or_create_overlay_layer() -> CanvasLayer:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return null

	var existing := scene_root.get_node_or_null(OVERLAY_LAYER_NAME) as CanvasLayer
	if existing:
		return existing

	var layer := CanvasLayer.new()
	layer.name = OVERLAY_LAYER_NAME
	layer.layer = OVERLAY_LAYER_INDEX
	scene_root.add_child(layer)
	return layer

extends Node2D

@onready var label: Label = $Label

var _pending_text := "+10"
var _pending_color := Color.GOLD
var _started := false


func setup(text: String, color: Color = Color.GOLD) -> void:
	_pending_text = text
	_pending_color = color
	_apply_pending_style()


func _ready() -> void:
	visible = false
	set_process(false)

	# Create a CanvasLayer so it renders on top of all UI
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	# Reparent the label to the canvas layer
	remove_child(label)
	canvas.add_child(label)
	_apply_pending_style()
	label.modulate = Color(1, 1, 1, 1)

	# Wait one frame so caller can finish assigning global_position after add_child.
	await get_tree().process_frame
	if not is_inside_tree() or not label:
		return

	_update_label_pos()
	visible = true
	set_process(true)
	_start_anim()


func _process(_delta: float) -> void:
	_update_label_pos()


func _update_label_pos() -> void:
	# Convert world position to screen space
	var screen_pos = get_global_transform_with_canvas() * Vector2.ZERO
	if label:
		label.position = screen_pos - label.size / 2.0


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
	# Float up 24 pixels (in world space)
	tween.tween_property(self, "position:y", -24.0, 0.6).as_relative().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Fade out the label
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(queue_free)

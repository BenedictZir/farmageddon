extends Node2D

@onready var label: Label = $Label


func setup(text: String, color: Color = Color.GOLD) -> void:
	label.text = text
	label.self_modulate = color


func _ready() -> void:
	# Create a CanvasLayer so it renders on top of all UI
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	# Reparent the label to the canvas layer
	remove_child(label)
	canvas.add_child(label)
	_update_label_pos()
	
	var tween = create_tween()
	# Float up 24 pixels (in world space)
	tween.tween_property(self, "position:y", -24.0, 0.6).as_relative().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Fade out the label
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(queue_free)


func _process(_delta: float) -> void:
	_update_label_pos()


func _update_label_pos() -> void:
	# Convert world position to screen space
	var screen_pos = get_global_transform_with_canvas() * Vector2.ZERO
	if label:
		label.position = screen_pos - label.size / 2.0

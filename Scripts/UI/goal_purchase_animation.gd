extends CanvasLayer
class_name GoalPurchaseAnimation

## PvZ-style goal purchase animation.
## The actual icon from the shop button is reparented and flies to center
## with light rays behind it, then a white flash covers the screen.

signal animation_finished

# -- Set these before adding to tree --
var goal_icon: Texture2D
var goal_name: String = "Goal"
var start_screen_position := Vector2.ZERO  # Shop button icon position
var source_icon_rect: TextureRect  # The actual icon node from the shop button

# -- Tuning --
const ICON_FINAL_SCALE := 5.0
const RAY_COUNT := 14
const RAY_LENGTH := 600.0  # Long enough to go off screen
const PARTICLE_COUNT := 10
const RAY_SPIN_SPEED := 0.4  # rad/s
const FLY_DURATION := 1.2  # Slower, more dramatic

# -- Internal --
var _dimmer: ColorRect
var _white_flash: ColorRect
var _rays_root: Node2D
var _icon_sprite: Sprite2D
var _vp_center: Vector2
var _active := false


func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS

	var vp_size := get_viewport().get_visible_rect().size
	_vp_center = vp_size / 2.0

	# Kill any lingering floating texts so they don't get stuck
	_kill_floating_texts()

	_build_dimmer()
	_build_rays()
	_build_icon()
	_build_white_flash()

	get_tree().paused = true
	GameManager.set_process(false)

	_active = true
	_run_animation()


func _process(delta: float) -> void:
	if _active and _rays_root and _icon_sprite:
		_rays_root.rotation += RAY_SPIN_SPEED * delta
		# Rays follow the icon position
		_rays_root.position = _icon_sprite.position


func _kill_floating_texts() -> void:
	# Remove any floating text nodes so they don't freeze on screen
	var texts = get_tree().get_nodes_in_group("floating_texts")
	for t in texts:
		t.queue_free()
	# Also check by class in current scene
	var scene = get_tree().current_scene
	if scene:
		for child in scene.get_children():
			if child is CanvasLayer and child.name == "FloatingTextOverlay":
				for label in child.get_children():
					label.queue_free()


# ── Node builders ────────────────────────────────────────────────────

func _build_dimmer() -> void:
	_dimmer = ColorRect.new()
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0, 0, 0, 0)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dimmer)


func _build_white_flash() -> void:
	_white_flash = ColorRect.new()
	_white_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white_flash.color = Color(1.0, 0.97, 0.85, 0)  # Warm golden-white, gentle
	_white_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white_flash)


func _build_rays() -> void:
	_rays_root = Node2D.new()
	_rays_root.position = start_screen_position
	_rays_root.modulate = Color(1, 1, 1, 0)
	_rays_root.scale = Vector2(0.08, 0.08)  # Start tiny, will grow
	add_child(_rays_root)

	for i in RAY_COUNT:
		var poly := Polygon2D.new()
		var angle := (TAU / RAY_COUNT) * i
		var dir := Vector2.from_angle(angle)
		var perp := dir.rotated(PI / 2.0)

		poly.polygon = PackedVector2Array([
			perp * 1.5,
			dir * RAY_LENGTH + perp * 24.0,
			dir * RAY_LENGTH,
			dir * RAY_LENGTH - perp * 24.0,
			-perp * 1.5,
		])
		poly.color = Color(1.0, 0.92, 0.5, 0.35) if (i % 2 == 0) else Color(1.0, 0.82, 0.3, 0.22)
		_rays_root.add_child(poly)


func _build_icon() -> void:
	_icon_sprite = Sprite2D.new()
	if goal_icon:
		_icon_sprite.texture = goal_icon
	_icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_sprite.position = start_screen_position
	_icon_sprite.scale = Vector2.ONE
	# Start with original modulate (black silhouette)
	_icon_sprite.modulate = Color(0, 0, 0, 1)
	add_child(_icon_sprite)

	# Hide the source icon on the button (it "left" the button)
	if source_icon_rect and is_instance_valid(source_icon_rect):
		source_icon_rect.visible = false


# ── Burst particles ──────────────────────────────────────────────────

func _spawn_burst() -> void:
	for i in range(PARTICLE_COUNT):
		var angle := (TAU / PARTICLE_COUNT) * i + randf_range(-0.3, 0.3)
		var dir := Vector2.from_angle(angle)
		var dist := randf_range(25.0, 55.0)
		var size := randf_range(2.0, 4.0)

		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([
			Vector2(-size, -size), Vector2(size, -size),
			Vector2(size, size), Vector2(-size, size),
		])
		p.color = Color(1.0, 0.9, 0.3, 1.0)
		p.position = start_screen_position
		add_child(p)

		var ptw := p.create_tween()
		ptw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		ptw.set_parallel(true)
		ptw.tween_property(p, "position", start_screen_position + dir * dist, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(p, "modulate:a", 0.0, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ptw.tween_property(p, "scale", Vector2.ZERO, 0.35)
		ptw.chain().tween_callback(p.queue_free)


# ── Animation timeline ───────────────────────────────────────────────

func _run_animation() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Phase 1: Burst particles + slight dim
	tw.tween_callback(_spawn_burst)
	tw.parallel().tween_property(_dimmer, "color:a", 0.55, 0.25)

	# Phase 2: Icon reveals from black silhouette to full color (smooth)
	tw.tween_property(_icon_sprite, "modulate", Color.WHITE, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Phase 3: Icon flies slowly to center + scales up + rays appear
	tw.tween_property(_icon_sprite, "position", _vp_center, FLY_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(
		_icon_sprite, "scale",
		Vector2.ONE * ICON_FINAL_SCALE, FLY_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Rays fade in + grow from small to full while icon moves
	tw.parallel().tween_property(_rays_root, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.2)
	tw.parallel().tween_property(_rays_root, "scale", Vector2.ONE, FLY_DURATION * 0.9)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.2)

	# Dim further
	tw.parallel().tween_property(_dimmer, "color:a", 0.7, 0.6)

	# Phase 4: Icon bounce on arrival
	tw.tween_property(
		_icon_sprite, "scale",
		Vector2.ONE * (ICON_FINAL_SCALE * 1.12), 0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(
		_icon_sprite, "scale",
		Vector2.ONE * ICON_FINAL_SCALE, 0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Phase 5: Hold for dramatic pause
	tw.tween_interval(0.7)

	# Phase 6: Gentle warm fade covers screen (not harsh white)
	tw.tween_property(_white_flash, "color:a", 1.0, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Hold
	tw.tween_interval(0.4)

	# Done
	tw.tween_callback(_on_done)


func _on_done() -> void:
	_active = false
	GameManager.set_process(true)
	animation_finished.emit()
	queue_free()

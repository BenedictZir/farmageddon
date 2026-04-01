extends Node

## HitEffects — shared utility for hit flash, sprite shake, and screen shake.
## Call play_hit(sprites, camera) from any character that takes damage.
## Call play_death(visual_node) for the ragdoll-fall death effect.

const FLASH_SHADER := preload("res://Shaders/hit_flash.gdshader")

var _hitstop_active := false

## Apply hit flash + sprite shake to an array of CanvasItems.
## Optionally pass a Camera2D for screen shake (player only).
func play_hit(sprites: Array, camera: Camera2D = null) -> void:
	_apply_flash(sprites)
	_apply_shake(sprites)
	if camera:
		_apply_screen_shake(camera)


func play_camera_shake(camera: Camera2D, magnitude := 2.0, duration := 0.25) -> void:
	if not camera:
		return
	_apply_screen_shake(camera, magnitude, duration)


func play_hit_stop(duration := 0.045, slowed_time_scale := 0.08) -> void:
	if _hitstop_active:
		return
	if duration <= 0.0:
		return

	var previous_time_scale := Engine.time_scale
	Engine.time_scale = clampf(slowed_time_scale, 0.01, 1.0)
	_hitstop_active = true

	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = previous_time_scale
		_hitstop_active = false
	, CONNECT_ONE_SHOT)


## Classic arcade death: flip, short arc, then fall off-screen.
## body is the root CharacterBody2D (enemy/helper).
## on_done is called when the animation finishes (for queue_free).
func play_death(body: Node2D, on_done: Callable = Callable()) -> void:
	# Disable physics so nothing interferes
	if body is CharacterBody2D:
		body.set_physics_process(false)
		body.set_process(false)
	
	# Freeze sprite on idle frame
	_freeze_idle(body)
	_set_death_flip_v(body)
	
	# Determine backward direction from facing
	var kick_dir := 1.0 # default: kick to the right
	var visual = body.get("visual") # EnemyVisual (AnimatedSprite2D)
	if visual and visual is AnimatedSprite2D:
		kick_dir = 1.0 if visual.flip_h else -1.0
	else:
		var helper_visual = body.get("helper_visual") # HelperVisual
		if helper_visual:
			var base_sprite = helper_visual.get("base")
			if base_sprite and base_sprite is AnimatedSprite2D:
				kick_dir = 1.0 if base_sprite.flip_h else -1.0
	
	var start_pos = body.global_position
	var tilt_dir = -kick_dir

	# Small arcade arc: pops up, travels a little sideways, then falls.
	var duration := 0.56
	var vel_x := 34.0 * kick_dir
	var vel_y := -300.0
	var gravity := 2000.0

	body.rotation_degrees = tilt_dir * 8.0

	var tw = body.create_tween()
	tw.tween_method(func(t: float):
		var x = start_pos.x + vel_x * t
		var y = start_pos.y + vel_y * t + 0.5 * gravity * t * t
		body.global_position = Vector2(x, y)
	, 0.0, duration, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	# Keep rotation expressive but not too aggressive.
	tw.parallel().tween_property(body, "rotation_degrees", tilt_dir * -34.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tw.finished.connect(func():
		_finish_death_offscreen(body, kick_dir, on_done)
	)


func _freeze_idle(body: Node2D) -> void:
	# Enemy: has 'visual' (EnemyVisual = AnimatedSprite2D)
	var visual = body.get("visual")
	if visual and visual is AnimatedSprite2D:
		if visual.sprite_frames and visual.sprite_frames.has_animation("idle"):
			visual.play("idle")
			visual.stop()
		return
	
	# Helper: has 'helper_visual' (HelperVisual = Node2D with Base/Hair/Tool)
	var helper_visual = body.get("helper_visual")
	if helper_visual:
		for child in helper_visual.get_children():
			if child is AnimatedSprite2D:
				if child.sprite_frames and child.sprite_frames.has_animation("idle"):
					child.play("idle")
					child.stop()


func _set_death_flip_v(body: Node2D) -> void:
	# Flip visible sprites vertically to match classic arcade death pose.
	var visual = body.get("visual")
	if visual and visual is AnimatedSprite2D:
		visual.flip_v = true
		return

	var helper_visual = body.get("helper_visual")
	if helper_visual:
		for child in helper_visual.get_children():
			if child is AnimatedSprite2D:
				child.flip_v = true


func _finish_death_offscreen(body: Node2D, kick_dir: float, on_done: Callable) -> void:
	if not is_instance_valid(body):
		return

	# Guarantee the body goes below map bounds before cleanup callback.
	var offscreen_y := _get_offscreen_bottom_y()
	if body.global_position.y < offscreen_y:
		var settle_pos := Vector2(body.global_position.x + 6.0 * kick_dir, offscreen_y)
		var settle_tw := body.create_tween()
		settle_tw.tween_property(body, "global_position", settle_pos, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		settle_tw.parallel().tween_property(body, "rotation_degrees", body.rotation_degrees + (-8.0 * kick_dir), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		settle_tw.finished.connect(func():
			_call_done_when_offscreen(body, on_done)
		)
		return

	_call_done_when_offscreen(body, on_done)


func _call_done_when_offscreen(body: Node2D, on_done: Callable) -> void:
	if not on_done.is_valid():
		return
	if not is_instance_valid(body) or not body.is_inside_tree():
		on_done.call()
		return

	var notifier := _find_visible_notifier(body)
	if notifier:
		if not notifier.is_on_screen():
			on_done.call()
		else:
			notifier.screen_exited.connect(func():
				if on_done.is_valid():
					on_done.call()
			, CONNECT_ONE_SHOT)
		return

	# Fallback for scenes without notifier node.
	if _is_outside_map(body.global_position):
		on_done.call()
	else:
		_wait_until_outside_map(body, on_done)


func _wait_until_outside_map(body: Node2D, on_done: Callable, attempts := 0) -> void:
	if not on_done.is_valid():
		return
	if not is_instance_valid(body) or not body.is_inside_tree():
		on_done.call()
		return
	if _is_outside_map(body.global_position) or attempts >= 18:
		on_done.call()
		return

	var timer := get_tree().create_timer(0.08)
	timer.timeout.connect(func():
		_wait_until_outside_map(body, on_done, attempts + 1)
	, CONNECT_ONE_SHOT)


func _find_visible_notifier(node: Node) -> VisibleOnScreenNotifier2D:
	for child in node.get_children():
		if child is VisibleOnScreenNotifier2D:
			return child
		var nested := _find_visible_notifier(child)
		if nested:
			return nested
	return null


func _get_offscreen_bottom_y() -> float:
	return GameManager.map_extents.y + 40.0


func _is_outside_map(pos: Vector2) -> bool:
	var extents := GameManager.map_extents
	var map_rect := Rect2(-extents, extents * 2.0).grow(24.0)
	return not map_rect.has_point(pos)


# ─── Internal ────────────────────────────────────────────

func _apply_flash(sprites: Array) -> void:
	for sprite in sprites:
		if not sprite is CanvasItem:
			continue
		var mat = sprite.material
		if not mat or not mat is ShaderMaterial:
			mat = ShaderMaterial.new()
			mat.shader = FLASH_SHADER
			sprite.material = mat
		
		var tw = sprite.create_tween()
		tw.tween_method(
			func(v): mat.set_shader_parameter("flash_amount", v),
			1.0, 0.0, 0.25
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_shake(sprites: Array) -> void:
	for sprite in sprites:
		if not sprite is Node2D:
			continue
		var origin = sprite.position
		var tw = sprite.create_tween()
		# 3 quick pings left-right, settling back
		tw.tween_property(sprite, "position:x", origin.x - 2.0, 0.04)
		tw.tween_property(sprite, "position:x", origin.x + 2.0, 0.04)
		tw.tween_property(sprite, "position:x", origin.x - 1.5, 0.04)
		tw.tween_property(sprite, "position:x", origin.x + 1.5, 0.04)
		tw.tween_property(sprite, "position:x", origin.x, 0.04)


func _apply_screen_shake(camera: Camera2D, magnitude := 2.0, duration := 0.25) -> void:
	var origin := camera.offset
	var tw := camera.create_tween()
	var steps := 6
	for i in range(steps):
		var t := duration / steps
		var m := magnitude * (1.0 - float(i) / steps)
		var offset := Vector2(randf_range(-m, m), randf_range(-m, m))
		tw.tween_property(camera, "offset", origin + offset, t)
	tw.tween_property(camera, "offset", origin, 0.06)

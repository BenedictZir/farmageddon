extends Node
class_name TutorialRunner

## Generic tutorial engine that plays a TutorialSequence (Resource).
## Supports DIALOG (click-to-advance), ACTION (signal/input wait),
## and timed hold steps (active or passive).
##
## REUSABLE: This script has no game-specific logic.
## Game-specific actions are delegated via custom_action_requested signal.

signal tutorial_completed
signal step_started(step_index: int)
signal step_completed(step_index: int)
signal custom_action_requested(action_name: String)

var spotlight: TutorialSpotlight
var dialog_box: TutorialDialogBox

var _steps: Array[TutorialStep] = []
var _current_step := -1
var _current_line := 0
var _is_running := false
var _waiting_for_action := false
var _waiting_for_input := false
var _waiting_input_name := ""
var _holding := false
var _hold_remaining := 0.0
var _hold_actions_active: Array[String] = []
var _transitioning := false
var _scene_root: Node
var _key_prompt_container: Node2D
var _tutorial_start_gold := -1
var _line_shown_time := 0.0
var _crop_harvest_wait_started_ready := false

@export_group("Key Prompt Layout")
@export var key_prompt_side_gap := 18.0
@export var key_prompt_vertical_offset := 0.0
@export var key_prompt_wasd_spacing := 36.0
@export var key_prompt_multi_spacing := 50.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _process(delta: float) -> void:
	var has_key_prompt := _key_prompt_container and is_instance_valid(_key_prompt_container)
	if has_key_prompt:
		_update_key_prompt_position()

	if _waiting_for_action and _is_waiting_for_crop_ready_step() and _is_crop_ready_for_current_step():
		_on_action_done(null, null, null, null, _current_step)
		return

	if _waiting_for_action and _is_waiting_for_crop_harvest_step() and _is_crop_harvested_for_current_step():
		_on_action_done(null, null, null, null, _current_step)
		return

	if _holding and not _hold_actions_active.is_empty():
		var any_pressed := false
		for action in _hold_actions_active:
			if Input.is_action_pressed(action):
				any_pressed = true
				break

		if any_pressed:
			_hold_remaining -= delta
			if _hold_remaining <= 0.0:
				_holding = false
				_hold_actions_active.clear()
				_update_process_state()
				_complete_step()

	# Re-evaluate process state each frame so crop-ready / crop-harvest polling
	# is not accidentally disabled when no key prompt is shown.
	_update_process_state()


## Start playing a TutorialSequence.
func start(sequence: TutorialSequence, spot: TutorialSpotlight, dialog: TutorialDialogBox, scene_root: Node) -> void:
	_steps.clear()
	for s in sequence.steps:
		_steps.append(s)
	spotlight = spot
	dialog_box = dialog
	_scene_root = scene_root
	_current_step = -1
	_current_line = 0
	_is_running = true
	_waiting_for_action = false
	_waiting_for_input = false
	_holding = false
	_tutorial_start_gold = CurrencyManager.gold if CurrencyManager else -1

	GameManager.tutorial_active = true
	AudioGlobal.play_music("res://Assets/Music/tutorial_music.ogg", -15)
	if dialog_box:
		dialog_box.set_npc_name(sequence.npc_name)
		if not dialog_box.skip_pressed.is_connected(_on_skip):
			dialog_box.skip_pressed.connect(_on_skip)

	_advance_step()


func skip() -> void:
	if not _is_running:
		return
	_cleanup()
	_finish()


func is_running() -> bool:
	return _is_running


# ── Input ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _is_running:
		return

	# Waiting for specific input action? Don't consume — let game systems also receive it.
	if _waiting_for_input and _waiting_input_name != "":
		if event.is_action_pressed(_waiting_input_name):
			_on_action_done()
			return

	# Block clicks during transitions, holds, or action-waits
	if _transitioning or _waiting_for_action or _waiting_for_input or _holding:
		return

	var should_advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			should_advance = true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if dialog_box and dialog_box.skip_button \
					and dialog_box.skip_button.get_global_rect().has_point(event.global_position):
				return
			should_advance = true

	if should_advance:
		get_viewport().set_input_as_handled()
		if dialog_box and dialog_box.is_typing():
			dialog_box.complete_typing()
		else:
			var current_time := Time.get_ticks_msec() / 1000.0
			if current_time - _line_shown_time >= 0.5:
				_advance_line()


# ── Step flow ────────────────────────────────────────────────────────

func _advance_step() -> void:
	_current_step += 1
	_current_line = 0
	_waiting_for_action = false
	_waiting_for_input = false
	_holding = false
	_crop_harvest_wait_started_ready = false
	_transitioning = true

	if _current_step >= _steps.size():
		_finish()
		return

	var step: TutorialStep = _steps[_current_step]
	step_started.emit(_current_step)

	# Unlock inputs
	if step.unlock_inputs.size() > 0:
		GameManager.unlock_inputs(step.unlock_inputs)

	# Custom actions
	for action_name in step.on_start_actions:
		custom_action_requested.emit(action_name)

	# Pause?
	if step.pause_game:
		get_tree().paused = true
	else:
		get_tree().paused = false

	# Spotlight
	if not step.wait_silent:
		_apply_spotlight(step)

	# Show key prompt
	_show_key_prompt(step)

	# Show first line
	var defer_first_line_until_signal := step.type == TutorialStep.StepType.ACTION \
		and step.wait_silent and step.action_signal_name != ""

	if step.lines.size() > 0 and dialog_box and not defer_first_line_until_signal:
		await get_tree().create_timer(0.25).timeout
		if not _is_running:
			return
		if step.camera_shake:
			var camera = get_viewport().get_camera_2d()
			if camera and HitEffects:
				HitEffects.play_camera_shake(camera, 3.5, 0.4)
		dialog_box.show_text(step.lines[0])
		_line_shown_time = Time.get_ticks_msec() / 1000.0
		_update_key_prompt_position()
		_transitioning = false
	elif dialog_box:
		if step.wait_silent or step.lines.is_empty():
			dialog_box.hide_text()
		_transitioning = false

	# Handle hold_duration (timed auto-advance)
	if step.hold_duration > 0.0:
		_holding = true
		_hold_remaining = step.hold_duration
		get_tree().paused = false

		if step.wait_silent:
			if dialog_box:
				dialog_box.hide_text()
			if spotlight:
				spotlight.hide_spotlight(false)
			_hide_key_prompt()

		if step.hold_actions.size() > 0:
			_hold_actions_active = []
			for a in step.hold_actions:
				_hold_actions_active.append(a)
			_update_process_state()
		else:
			_hold_actions_active = []
			await get_tree().create_timer(step.hold_duration).timeout
			if not _is_running or _current_step >= _steps.size():
				return
			if _holding:
				_holding = false
				_complete_step()
		return

	# Handle ACTION type
	if step.type == TutorialStep.StepType.ACTION:
		if _is_action_already_done(step):
			await get_tree().create_timer(0.05).timeout
			if _is_running:
				_complete_step()
			return

		if step.action_signal_name == "crop_ready":
			_waiting_for_action = true
			get_tree().paused = false
			_update_process_state()

			if _is_crop_ready_for_current_step():
				await get_tree().create_timer(0.05).timeout
				if _is_running:
					_on_action_done(null, null, null, null, _current_step)
			return

		if step.action_signal_name == "crop_harvested":
			_waiting_for_action = true
			_crop_harvest_wait_started_ready = _is_crop_ready_for_current_step()
			get_tree().paused = false
			_update_process_state()

			if _is_crop_harvested_for_current_step():
				await get_tree().create_timer(0.05).timeout
				if _is_running:
					_on_action_done(null, null, null, null, _current_step)
			return

		if step.action_input_name != "":
			_waiting_for_input = true
			_waiting_input_name = step.action_input_name
			get_tree().paused = false
			return

		var source := _resolve_action_source(step)
		if source and step.action_signal_name != "" and source.has_signal(step.action_signal_name):
			_waiting_for_action = true
			get_tree().paused = false
			var step_guard := _current_step

			if step.wait_silent:
				if dialog_box:
					dialog_box.hide_text()
				if spotlight:
					spotlight.hide_spotlight(false)
				_hide_key_prompt()
				source.connect(step.action_signal_name, Callable(self, "_on_signal_action_done").bind(step_guard), CONNECT_ONE_SHOT)
			else:
				source.connect(step.action_signal_name, Callable(self, "_on_action_done").bind(step_guard), CONNECT_ONE_SHOT)
			return


func _is_action_already_done(step: TutorialStep) -> bool:
	# Prevent softlock on buy-steps when the player purchased before reaching the step.
	if step.action_signal_name == "gold_changed" and step.action_source_autoload == "CurrencyManager":
		if _tutorial_start_gold >= 0 and CurrencyManager.gold < _tutorial_start_gold:
			return true
		if PlayerRef.instance and PlayerRef.instance.is_carrying:
			return true

	return false


func _advance_line() -> void:
	if _current_step < 0 or _current_step >= _steps.size():
		return
	var step: TutorialStep = _steps[_current_step]
	_current_line += 1
	if _current_line < step.lines.size():
		dialog_box.show_text(step.lines[_current_line])
		_line_shown_time = Time.get_ticks_msec() / 1000.0
		_update_key_prompt_position()
	else:
		_complete_step()


func _complete_step() -> void:
	_transitioning = true
	_hide_key_prompt()
	step_completed.emit(_current_step)
	_waiting_for_action = false
	_waiting_for_input = false
	_holding = false

	var should_hide_dialog := false
	if _current_step >= 0 and _current_step < _steps.size():
		var current_step: TutorialStep = _steps[_current_step]
		should_hide_dialog = current_step.wait_silent

	var next_step_index := _current_step + 1
	if not should_hide_dialog and next_step_index >= 0 and next_step_index < _steps.size():
		var next_step: TutorialStep = _steps[next_step_index]
		should_hide_dialog = next_step.wait_silent

	if dialog_box and should_hide_dialog:
		dialog_box.hide_text()

	await get_tree().create_timer(0.2).timeout
	if not _is_running:
		return
	_advance_step()


func _on_action_done(_a = null, _b = null, _c = null, _d = null, expected_step := -1) -> void:
	if expected_step != -1 and expected_step != _current_step:
		return
	if not _waiting_for_action and not _waiting_for_input:
		return
	_waiting_for_action = false
	_waiting_for_input = false
	_crop_harvest_wait_started_ready = false

	var step: TutorialStep = _steps[_current_step]
	_current_line += 1
	if _current_line < step.lines.size():
		get_tree().paused = true
		dialog_box.show_text(step.lines[_current_line])
		_line_shown_time = Time.get_ticks_msec() / 1000.0
		_update_key_prompt_position()
	else:
		_complete_step()


## Signal-based action done — shows dialog from line 0 since it was hidden.
func _on_signal_action_done(_a = null, _b = null, _c = null, _d = null, expected_step := -1) -> void:
	if expected_step != -1 and expected_step != _current_step:
		return
	if not _waiting_for_action:
		return
	_waiting_for_action = false
	_crop_harvest_wait_started_ready = false

	var step: TutorialStep = _steps[_current_step]

	# Optional delay before showing dialog (e.g. let enemy walk into view)
	if step.signal_delay > 0.0:
		await get_tree().create_timer(step.signal_delay).timeout
		if not _is_running:
			return

	get_tree().paused = true
	_current_line = 0

	var used_signal_target_spotlight := _apply_signal_target_spotlight(step, _a, _b, _c, _d)
	if not used_signal_target_spotlight:
		_apply_spotlight(step)
	_show_key_prompt(step)

	if step.lines.size() > 0 and dialog_box:
		await get_tree().create_timer(0.2).timeout
		if not _is_running:
			return
		if step.camera_shake:
			var camera = get_viewport().get_camera_2d()
			if camera and HitEffects:
				HitEffects.play_camera_shake(camera, 3.5, 0.4)
		dialog_box.show_text(step.lines[0])
		_line_shown_time = Time.get_ticks_msec() / 1000.0
		_update_key_prompt_position()


func _on_skip() -> void:
	skip()


# ── Spotlight ────────────────────────────────────────────────────────

func _apply_spotlight(step: TutorialStep) -> void:
	if not spotlight:
		return
	if step.spotlight_shape == TutorialStep.SpotlightShape.NONE:
		spotlight.hide_spotlight(false)
		return

	spotlight.set_shape(
		TutorialSpotlight.Shape.ELLIPSE if step.spotlight_shape == TutorialStep.SpotlightShape.CIRCLE \
		else TutorialSpotlight.Shape.RECTANGLE
	)

	if _try_apply_combined_control_spotlight(step):
		return

	if step.spotlight_node_path != "":
		var target := _scene_root.get_node_or_null(step.spotlight_node_path)
		if target is Control:
			spotlight.focus_on_control(target, step.spotlight_padding)
			return
		elif target is Node2D:
			spotlight.focus_on_node2d(target, step.spotlight_size)
			return

	spotlight.show_spotlight(step.spotlight_position, step.spotlight_size)


func _try_apply_combined_control_spotlight(step: TutorialStep) -> bool:
	if not _scene_root:
		return false
	if step.spotlight_node_path == "" or step.spotlight_secondary_node_path == "":
		return false

	var primary := _scene_root.get_node_or_null(step.spotlight_node_path)
	var secondary := _scene_root.get_node_or_null(step.spotlight_secondary_node_path)
	if not (primary is Control and secondary is Control):
		return false

	var pad := step.spotlight_padding
	var primary_rect: Rect2 = (primary as Control).get_global_rect()
	primary_rect.position -= pad
	primary_rect.size += pad * 2.0

	var secondary_rect: Rect2 = (secondary as Control).get_global_rect()
	secondary_rect.position -= pad
	secondary_rect.size += pad * 2.0

	var merged := primary_rect.merge(secondary_rect)
	spotlight.focus_on_screen_rect(merged, Vector2.ZERO)
	return true


func _apply_signal_target_spotlight(step: TutorialStep, a = null, b = null, c = null, d = null) -> bool:
	if not spotlight or not step.spotlight_signal_target:
		return false

	spotlight.set_shape(
		TutorialSpotlight.Shape.ELLIPSE if step.spotlight_shape == TutorialStep.SpotlightShape.CIRCLE \
		else TutorialSpotlight.Shape.RECTANGLE
	)

	for arg in [a, b, c, d]:
		if arg is Node2D and is_instance_valid(arg):
			spotlight.focus_on_node2d(arg, step.spotlight_size)
			return true
		if arg is Control and is_instance_valid(arg):
			spotlight.focus_on_control(arg, step.spotlight_padding)
			return true

	return false


# ── Key Prompt ───────────────────────────────────────────────────────

func _show_key_prompt(step: TutorialStep) -> void:
	_hide_key_prompt()
	if step.key_prompt.is_empty():
		return
	if not dialog_box:
		return

	var key_tokens := _parse_key_prompt_tokens(step.key_prompt)
	if key_tokens.is_empty():
		return

	# WASD special case — 4 keys arranged like keyboard
	if key_tokens.size() == 1 and key_tokens[0] == "WASD":
		_show_wasd_prompt()
		return

	if key_tokens.size() == 1:
		# Single key prompt
		var tex := _load_key_texture(key_tokens[0])
		if not tex:
			return

		var sprite := _create_key_sprite(tex)
		sprite.position = Vector2.ZERO

		_key_prompt_container = Node2D.new()
		_key_prompt_container.add_child(sprite)
		dialog_box.add_child(_key_prompt_container)
		_update_key_prompt_position()
		_update_process_state()
		return

	_show_multi_key_prompt(key_tokens)


func _show_wasd_prompt() -> void:
	_key_prompt_container = Node2D.new()

	var keys := ["W", "A", "S", "D"]
	var spacing := key_prompt_wasd_spacing
	# Layout:   [W]
	#         [A][S][D]
	var positions := [
		Vector2(0, -spacing * 0.5),           # W — top center
		Vector2(-spacing, spacing * 0.5),      # A — bottom left
		Vector2(0, spacing * 0.5),             # S — bottom center
		Vector2(spacing, spacing * 0.5),       # D — bottom right
	]

	for i in keys.size():
		var tex := _load_key_texture(keys[i])
		if not tex:
			continue
		var sprite := _create_key_sprite(tex)
		sprite.position = positions[i]
		_key_prompt_container.add_child(sprite)

	if _key_prompt_container.get_child_count() == 0:
		_key_prompt_container.queue_free()
		_key_prompt_container = null
		return

	dialog_box.add_child(_key_prompt_container)
	_update_key_prompt_position()
	_update_process_state()


func _show_multi_key_prompt(keys: Array[String]) -> void:
	_key_prompt_container = Node2D.new()

	var spacing := key_prompt_multi_spacing
	var half_span := (float(keys.size() - 1) * spacing) * 0.5

	for i in keys.size():
		var tex := _load_key_texture(keys[i])
		if not tex:
			continue

		var sprite := _create_key_sprite(tex)
		sprite.position = Vector2((float(i) * spacing) - half_span, 0)
		_key_prompt_container.add_child(sprite)

	if _key_prompt_container.get_child_count() == 0:
		_key_prompt_container.queue_free()
		_key_prompt_container = null
		return

	dialog_box.add_child(_key_prompt_container)
	_update_key_prompt_position()
	_update_process_state()


func _update_key_prompt_position() -> void:
	if not dialog_box:
		return
	if not (_key_prompt_container and is_instance_valid(_key_prompt_container)):
		return

	var bubble_rect := _get_dialog_bubble_rect()
	var prompt_half_size := _get_key_prompt_half_size()

	_key_prompt_container.position = Vector2(
		bubble_rect.position.x + bubble_rect.size.x + key_prompt_side_gap + prompt_half_size.x,
		bubble_rect.position.y + (bubble_rect.size.y * 0.5) + key_prompt_vertical_offset
	)


func _get_dialog_bubble_rect() -> Rect2:
	if not dialog_box:
		return Rect2()

	var bubble_node := dialog_box.get_node_or_null("Bubble") as Control
	if bubble_node:
		return Rect2(bubble_node.position, bubble_node.size)

	return Rect2(Vector2.ZERO, dialog_box.size)


func _get_key_prompt_half_size() -> Vector2:
	if not (_key_prompt_container and is_instance_valid(_key_prompt_container)):
		return Vector2.ZERO

	var max_x := 0.0
	var max_y := 0.0

	for child in _key_prompt_container.get_children():
		if not (child is Node2D):
			continue

		var node2d := child as Node2D
		var half_w := 0.0
		var half_h := 0.0

		if child is AnimatedSprite2D:
			var sprite := child as AnimatedSprite2D
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("default") \
					and sprite.sprite_frames.get_frame_count("default") > 0:
				var frame_tex := sprite.sprite_frames.get_frame_texture("default", 0)
				if frame_tex:
					var tex_size := frame_tex.get_size()
					half_w = float(tex_size.x) * sprite.scale.x * 0.5
					half_h = float(tex_size.y) * sprite.scale.y * 0.5

		max_x = maxf(max_x, absf(node2d.position.x) + half_w)
		max_y = maxf(max_y, absf(node2d.position.y) + half_h)

	return Vector2(max_x, max_y)


func _update_process_state() -> void:
	var has_key_prompt := _key_prompt_container and is_instance_valid(_key_prompt_container)
	var needs_hold_input := _holding and not _hold_actions_active.is_empty()
	var needs_crop_ready_poll := _waiting_for_action and (_is_waiting_for_crop_ready_step() or _is_waiting_for_crop_harvest_step())
	set_process(has_key_prompt or needs_hold_input or needs_crop_ready_poll)


func _is_waiting_for_crop_ready_step() -> bool:
	if _current_step < 0 or _current_step >= _steps.size():
		return false
	var step: TutorialStep = _steps[_current_step]
	return step.type == TutorialStep.StepType.ACTION and step.action_signal_name == "crop_ready"


func _is_waiting_for_crop_harvest_step() -> bool:
	if _current_step < 0 or _current_step >= _steps.size():
		return false
	var step: TutorialStep = _steps[_current_step]
	return step.type == TutorialStep.StepType.ACTION and step.action_signal_name == "crop_harvested"


func _is_crop_ready_for_current_step() -> bool:
	if _current_step < 0 or _current_step >= _steps.size():
		return false

	var step: TutorialStep = _steps[_current_step]
	var source: Node = null
	if step.action_source_node_path != "" and _scene_root:
		source = _scene_root.get_node_or_null(step.action_source_node_path)

	if not source:
		return _is_crop_ready_in_node(_scene_root)

	return _is_crop_ready_in_node(source)


func _is_crop_harvested_for_current_step() -> bool:
	if not _crop_harvest_wait_started_ready:
		return false
	return not _is_crop_ready_for_current_step()


func _is_crop_ready_in_node(node: Node) -> bool:
	if not node:
		return false

	if node.has_method("is_harvestable") and node.call("is_harvestable"):
		return true

	for child in node.get_children():
		if _is_crop_ready_in_node(child):
			return true

	return false


func _parse_key_prompt_tokens(raw_prompt: String) -> Array[String]:
	var prompt := raw_prompt.strip_edges().to_upper()
	if prompt.is_empty():
		return []

	if prompt == "WASD":
		return ["WASD"]

	for sep in ["+", ",", "/", "|"]:
		prompt = prompt.replace(sep, " ")

	var tokens: Array[String] = []
	for part in prompt.split(" ", false):
		var key_name := part.strip_edges()
		if key_name.is_empty():
			continue
		if not tokens.has(key_name):
			tokens.append(key_name)

	return tokens


func _load_key_texture(key_name: String) -> Texture2D:
	var key_path := "res://Assets/Key/%s.png" % key_name
	return load(key_path) as Texture2D


func _create_key_sprite(tex: Texture2D) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	var img := tex.get_image()
	var frame_w := img.get_width() / 2
	var frame_h := img.get_height()

	var atlas_normal := AtlasTexture.new()
	atlas_normal.atlas = tex
	atlas_normal.region = Rect2(0, 0, frame_w, frame_h)

	var atlas_pressed := AtlasTexture.new()
	atlas_pressed.atlas = tex
	atlas_pressed.region = Rect2(frame_w, 0, frame_w, frame_h)

	frames.set_animation_speed("default", 3.0)
	frames.set_animation_loop("default", true)
	frames.add_frame("default", atlas_normal)
	frames.add_frame("default", atlas_pressed)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2(2.0, 2.0)
	sprite.play("default")
	return sprite


func _hide_key_prompt() -> void:
	if _key_prompt_container and is_instance_valid(_key_prompt_container):
		_key_prompt_container.queue_free()
		_key_prompt_container = null
	_update_process_state()


# ── Action source resolution ─────────────────────────────────────────

func _resolve_action_source(step: TutorialStep) -> Object:
	if step.action_source_autoload != "":
		var autoload := get_tree().root.get_node_or_null(step.action_source_autoload)
		if autoload:
			return autoload
	if step.action_source_node_path != "" and _scene_root:
		return _scene_root.get_node_or_null(step.action_source_node_path)
	return null


# ── Cleanup ──────────────────────────────────────────────────────────

func _cleanup() -> void:
	_waiting_for_action = false
	_waiting_for_input = false
	_holding = false
	set_process(false)
	_hold_actions_active.clear()
	_hide_key_prompt()
	if dialog_box:
		dialog_box.hide_text()
	if spotlight:
		spotlight.hide_spotlight(false)


func _finish() -> void:
	_is_running = false
	_cleanup()

	GameManager.unlock_all_inputs()

	get_tree().paused = false
	tutorial_completed.emit()
	AudioGlobal.play_music("res://Assets/Music/menu_music.wav", -12)

extends Control
class_name TutorialDialogBox
## Reusable dialog box with dynamic 9-slice bubble + tail + Chicky animation.

signal typing_started
signal typing_finished
signal skip_pressed

@onready var bubble: NinePatchRect = $Bubble
@onready var tail: TextureRect = $Bubble/Tail
@onready var chicky: AnimatedSprite2D = $Chicky
@onready var margin_box: MarginContainer = $Bubble/Margin
@onready var content_vbox: VBoxContainer = $Bubble/Margin/VBox
@onready var name_label: Label = $Bubble/Margin/VBox/NameLabel
@onready var dialog_label: RichTextLabel = $Bubble/Margin/VBox/DialogLabel
@onready var continue_arrow: Label = $ContinueArrow
@onready var skip_button: Button = $SkipButton
@onready var dialog_bleep: AudioStreamPlayer = $DialogBleep

@export var appear_duration := 0.15
@export var min_bubble_width := 220.0
@export var max_bubble_width := 560.0
@export var min_bubble_height := 44.0
@export var max_bubble_height := 96.0
@export var bubble_vertical_padding := 4.0
@export var per_extra_line_height_factor := 0.62
@export var bubble_left_margin := 14.0
@export var bubble_bottom_margin := 6.0
@export var tail_left_offset := 10.0
@export var chicky_offset_from_tail := Vector2(8, 30)

var _is_typing := false
var _fade_tween: Tween
var _typing_tween: Tween
var _arrow_tween: Tween
var _mouth_tween: Tween
var _last_text := ""

var _patch_left := 0
var _patch_top := 0
var _patch_right := 0
var _patch_bottom := 0

const SLICE_TOP_LEFT := "res://Assets/DialogueBox/TopLeft.png"
const SLICE_TOP_MID := "res://Assets/DialogueBox/TopMid.png"
const SLICE_TOP_RIGHT := "res://Assets/DialogueBox/TopRight.png"
const SLICE_MID_LEFT := "res://Assets/DialogueBox/MiddleLeft.png"
const SLICE_MID := "res://Assets/DialogueBox/Middle.png"
const SLICE_MID_RIGHT := "res://Assets/DialogueBox/MiddleRight.png"
const SLICE_BOTTOM_LEFT := "res://Assets/DialogueBox/BottomLeft.png"
const SLICE_BOTTOM_MID := "res://Assets/DialogueBox/BottomMid.png"
const SLICE_BOTTOM_RIGHT := "res://Assets/DialogueBox/BottomRight.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	modulate.a = 0.0
	_apply_bubble_nine_patch_texture()

	if dialog_label:
		dialog_label.bbcode_enabled = true
		dialog_label.visible_ratio = 0.0
		dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if continue_arrow:
		continue_arrow.visible = false

	if skip_button:
		skip_button.pressed.connect(func(): skip_pressed.emit())

	if chicky and chicky.sprite_frames and chicky.sprite_frames.has_animation("idle"):
		chicky.play("idle")

	if tail and tail.texture:
		var tail_size := tail.texture.get_size()
		tail.custom_minimum_size = tail_size
		tail.size = tail_size
		tail.stretch_mode = TextureRect.STRETCH_KEEP

	if not resized.is_connected(_on_layout_changed):
		resized.connect(_on_layout_changed)
	if not get_viewport().size_changed.is_connected(_on_layout_changed):
		get_viewport().size_changed.connect(_on_layout_changed)

	_update_bubble_layout(_last_text)


## Show text with typewriter effect
func show_text(text: String, chars_per_second := 35.0) -> void:
	_last_text = text
	_update_bubble_layout(text)

	if dialog_label:
		dialog_label.text = text
		dialog_label.visible_ratio = 0.0

	if continue_arrow:
		continue_arrow.visible = false

	_show_box()
	# Wait for box to appear before typing
	await get_tree().create_timer(appear_duration).timeout
	_start_typewriter(text, chars_per_second)


## Hide the dialog box
func hide_text() -> void:
	_stop_typewriter()
	_stop_mouth()
	_hide_box()


## Check if currently typing
func is_typing() -> bool:
	return _is_typing


## Complete typing instantly
func complete_typing() -> void:
	if not _is_typing:
		return
	_stop_typewriter()
	_stop_mouth()
	if dialog_label:
		dialog_label.visible_ratio = 1.0
	if continue_arrow:
		continue_arrow.visible = true
		_blink_arrow()
	typing_finished.emit()


## Set NPC name
func set_npc_name(n: String) -> void:
	if name_label:
		name_label.text = n


## Set portrait sprite frames (assign externally)
func set_portrait_frames(frames: SpriteFrames) -> void:
	if chicky:
		chicky.sprite_frames = frames


# ── Internal ─────────────────────────────────────────────────────────

func _show_box() -> void:
	visible = true
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(self, "modulate:a", 1.0, appear_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide_box() -> void:
	if _fade_tween:
		_fade_tween.kill()
	if _arrow_tween:
		_arrow_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(self, "modulate:a", 0.0, appear_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(func(): visible = false)


func _start_typewriter(text: String, cps: float) -> void:
	if not dialog_label or text.is_empty():
		return

	_is_typing = true
	typing_started.emit()

	# Start mouth animation
	_start_mouth()

	# Play bleep if available
	if dialog_bleep and dialog_bleep.stream:
		dialog_bleep.play()

	var plain := _strip_bbcode(text)
	var duration := plain.length() / maxf(cps, 1.0)

	if _typing_tween:
		_typing_tween.kill()
	_typing_tween = create_tween()
	_typing_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_typing_tween.tween_property(dialog_label, "visible_ratio", 1.0, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	_typing_tween.tween_callback(_on_typing_complete)


func _stop_typewriter() -> void:
	_is_typing = false
	if _typing_tween:
		_typing_tween.kill()
	if dialog_bleep and dialog_bleep.playing:
		dialog_bleep.stop()


func _on_typing_complete() -> void:
	_is_typing = false
	_stop_mouth()
	if dialog_bleep and dialog_bleep.playing:
		dialog_bleep.stop()
	if continue_arrow:
		continue_arrow.visible = true
		_blink_arrow()
	typing_finished.emit()


# ── Mouth animation ──────────────────────────────────────────────────

func _start_mouth() -> void:
	if not chicky or not chicky.sprite_frames:
		return
	_stop_mouth()
	if chicky.sprite_frames.has_animation("talking"):
		chicky.play("talking")


func _stop_mouth() -> void:
	if _mouth_tween:
		_mouth_tween.kill()
		_mouth_tween = null
	if chicky and chicky.sprite_frames and chicky.sprite_frames.has_animation("idle"):
		chicky.play("idle")


# ── Continue arrow blink ─────────────────────────────────────────────

func _blink_arrow() -> void:
	if not continue_arrow:
		return
	if _arrow_tween:
		_arrow_tween.kill()
	continue_arrow.modulate.a = 1.0
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_arrow_tween.tween_property(continue_arrow, "modulate:a", 0.2, 0.2)
	_arrow_tween.tween_property(continue_arrow, "modulate:a", 1.0, 0.2)


func _on_layout_changed() -> void:
	_update_bubble_layout(_last_text)


func _update_bubble_layout(text: String) -> void:
	if not bubble:
		return

	var viewport_width := get_viewport_rect().size.x
	var max_allowed := maxf(min_bubble_width, minf(max_bubble_width, viewport_width - bubble_left_margin - 20.0))
	var estimated_text_width := _estimate_text_width(text)
	var target_width := clampf(estimated_text_width + 44.0, min_bubble_width, max_allowed)
	var target_height := _estimate_bubble_height(text, target_width)

	bubble.size = Vector2(target_width, target_height)
	bubble.position = Vector2(bubble_left_margin, size.y - bubble_bottom_margin - target_height)

	if tail:
		var tail_size := tail.size
		tail.position = Vector2(tail_left_offset, target_height)

	if chicky:
		var tail_world_pos := bubble.position + tail.position
		chicky.position = tail_world_pos + chicky_offset_from_tail

	if continue_arrow:
		continue_arrow.position = bubble.position + Vector2(target_width - 15.0, target_height - 16.0)

	if skip_button and skip_button.visible:
		skip_button.position = bubble.position + Vector2(target_width - skip_button.size.x - 8.0, 6.0)


func _estimate_text_width(text: String) -> float:
	var plain := _strip_bbcode(text)
	if plain.is_empty():
		return min_bubble_width

	if dialog_label:
		var font := dialog_label.get_theme_font("normal_font")
		var font_size := dialog_label.get_theme_font_size("normal_font_size")
		if font:
			# Get exact width of text on one line, plus a tiny buffer
			return font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 4.0

	return float(plain.length()) * 7.0


func _estimate_bubble_height(text: String, bubble_width: float) -> float:
	var plain := _strip_bbcode(text)
	if plain.is_empty():
		plain = " "

	var margin_left := 16.0
	var margin_top := 8.0
	var margin_right := 8.0
	var margin_bottom := 8.0
	var row_separation := 4.0

	if margin_box:
		margin_left = float(margin_box.get_theme_constant("margin_left"))
		margin_top = float(margin_box.get_theme_constant("margin_top"))
		margin_right = float(margin_box.get_theme_constant("margin_right"))
		margin_bottom = float(margin_box.get_theme_constant("margin_bottom"))

	if content_vbox:
		row_separation = float(content_vbox.get_theme_constant("separation"))

	var inner_width := maxf(1.0, bubble_width - margin_left - margin_right - 4.0)

	var name_height := 10.0
	if name_label:
		var name_font := name_label.get_theme_font("font")
		var name_size := name_label.get_theme_font_size("font_size")
		if name_font:
			name_height = name_font.get_height(name_size)

	var body_font_size := 12
	if dialog_label:
		body_font_size = dialog_label.get_theme_font_size("normal_font_size")

	var total_text_width := _estimate_text_width(text)
	var wrapped_line_count := maxi(1, int(ceil(total_text_width / inner_width)))
	var explicit_line_count := maxi(1, plain.split("\n", false).size())
	var line_count := maxi(wrapped_line_count, explicit_line_count)

	var base_line_height := float(body_font_size) + 1.0
	var extra_line_height := maxf(2.0, base_line_height * per_extra_line_height_factor)
	var text_height := base_line_height + float(maxi(0, line_count - 1)) * extra_line_height
	var desired := margin_top + margin_bottom + name_height + row_separation + text_height + bubble_vertical_padding
	return clampf(desired, min_bubble_height, max_bubble_height)


func _apply_bubble_nine_patch_texture() -> void:
	if not bubble:
		return

	var result := _build_bubble_texture()
	if result == null:
		push_warning("[TutorialDialogBox] Failed to build bubble texture from 9-slice assets.")
		return

	bubble.texture = result
	bubble.patch_margin_left = _patch_left
	bubble.patch_margin_top = _patch_top
	bubble.patch_margin_right = _patch_right
	bubble.patch_margin_bottom = _patch_bottom


func _build_bubble_texture() -> Texture2D:
	var top_left := _load_slice_image(SLICE_TOP_LEFT)
	var top_mid := _load_slice_image(SLICE_TOP_MID)
	var top_right := _load_slice_image(SLICE_TOP_RIGHT)
	var mid_left := _load_slice_image(SLICE_MID_LEFT)
	var mid := _load_slice_image(SLICE_MID)
	var mid_right := _load_slice_image(SLICE_MID_RIGHT)
	var bottom_left := _load_slice_image(SLICE_BOTTOM_LEFT)
	var bottom_mid := _load_slice_image(SLICE_BOTTOM_MID)
	var bottom_right := _load_slice_image(SLICE_BOTTOM_RIGHT)

	if not top_left or not top_mid or not top_right or not mid_left or not mid or not mid_right \
			or not bottom_left or not bottom_mid or not bottom_right:
		return null

	var left_w := top_left.get_width()
	var mid_w := top_mid.get_width()
	var right_w := top_right.get_width()
	var top_h := top_left.get_height()
	var mid_h := mid.get_height()
	var bottom_h := bottom_left.get_height()

	_patch_left = left_w
	_patch_top = top_h
	_patch_right = right_w
	_patch_bottom = bottom_h

	var atlas := Image.create(left_w + mid_w + right_w, top_h + mid_h + bottom_h, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))

	_blit_slice(atlas, top_left, Vector2i(0, 0))
	_blit_slice(atlas, top_mid, Vector2i(left_w, 0))
	_blit_slice(atlas, top_right, Vector2i(left_w + mid_w, 0))

	_blit_slice(atlas, mid_left, Vector2i(0, top_h))
	_blit_slice(atlas, mid, Vector2i(left_w, top_h))
	_blit_slice(atlas, mid_right, Vector2i(left_w + mid_w, top_h))

	_blit_slice(atlas, bottom_left, Vector2i(0, top_h + mid_h))
	_blit_slice(atlas, bottom_mid, Vector2i(left_w, top_h + mid_h))
	_blit_slice(atlas, bottom_right, Vector2i(left_w + mid_w, top_h + mid_h))

	return ImageTexture.create_from_image(atlas)


func _load_slice_image(path: String) -> Image:
	var tex := load(path) as Texture2D
	if not tex:
		push_warning("[TutorialDialogBox] Missing slice texture: %s" % path)
		return null
	return tex.get_image()


func _blit_slice(target: Image, source: Image, at: Vector2i) -> void:
	target.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), at)


# ── Utility ──────────────────────────────────────────────────────────

func _strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)

extends Node


var _cursor_default: ImageTexture
var _cursor_pointer: ImageTexture
var _cursor_click: ImageTexture

var _is_pointer := false

const CURSOR_SCALE := 0.3


func _ready() -> void:
	_cursor_default = _load_scaled("res://Assets/CustomCursor/cursor.png")
	_cursor_pointer = _load_scaled("res://Assets/CustomCursor/pointer.png")
	_cursor_click = _load_scaled("res://Assets/CustomCursor/click.png")
	set_default()


func _load_scaled(path: String) -> ImageTexture:
	var tex := load(path) as Texture2D
	if not tex:
		push_warning("Cursor texture missing: %s" % path)
		return null

	var img := tex.get_image()
	if not img:
		push_warning("Failed to read cursor image: %s" % path)
		return null

	var new_w := int(img.get_width() * CURSOR_SCALE)
	var new_h := int(img.get_height() * CURSOR_SCALE)
	new_w = maxi(1, new_w)
	new_h = maxi(1, new_h)
	img.resize(new_w, new_h, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _input(event: InputEvent) -> void:
	if not _is_pointer:
		return
	# When in pointer mode, show click cursor on mouse press
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _cursor_click:
					Input.set_custom_mouse_cursor(_cursor_click)
			else:
				if _cursor_pointer:
					Input.set_custom_mouse_cursor(_cursor_pointer)


## Set cursor to default (normal gameplay)
func set_default() -> void:
	_is_pointer = false
	if _cursor_default:
		Input.set_custom_mouse_cursor(_cursor_default)
	else:
		Input.set_custom_mouse_cursor(null)


## Set cursor to pointer (hovering something clickable like shop UI)
func set_pointer() -> void:
	if not _cursor_pointer:
		set_default()
		return
	_is_pointer = true
	Input.set_custom_mouse_cursor(_cursor_pointer)

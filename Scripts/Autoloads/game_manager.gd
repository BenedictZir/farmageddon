extends CanvasLayer

## Autoload that manages cross-level data, win/lose conditions, and the Game Loop UI.

@onready var color_rect: ColorRect = $ColorRect
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var retry_button: Button = $VBoxContainer/HBoxContainer/RetryButton
@onready var next_button: Button = $VBoxContainer/HBoxContainer/NextButton
@onready var vbox: VBoxContainer = $VBoxContainer

var map_extents := Vector2(320, 180) # Default size
var current_level_path := ""

var _game_over := false
var _check_timer := 0.0


func _ready() -> void:
	hide_ui()
	retry_button.pressed.connect(_on_retry_pressed)
	next_button.pressed.connect(_on_next_pressed)


func register_level(extents: Vector2, scene_path: String) -> void:
	map_extents = extents
	current_level_path = scene_path
	_game_over = false
	hide_ui()


func _process(delta: float) -> void:
	if _game_over:
		return
	
	_check_timer += delta
	if _check_timer >= 1.0:
		_check_timer = 0.0
		_check_lose_condition()


func _check_lose_condition() -> void:
	# Lose if: Gold < lowest shop price (assuming 15) AND
	# No crops planted AND player not holding any seeds/crops.
	if CurrencyManager.gold >= 15:
		return
	
	var player = PlayerRef.instance
	if player and player.is_carrying:
		var held = player.get("_held_item")
		if held is CropData:
			return # Still has seeds/crops to plant/sell
			
	var planted_crops = get_tree().get_nodes_in_group("plantable_tiles").filter(func(tile): return tile.get("occupied") == true)
	if planted_crops.size() > 0:
		return # Crops are growing
		
	# No money, no seeds, no crops growing = softlock
	lose()


func win() -> void:
	if _game_over:
		return
	_game_over = true
	get_tree().paused = true
	title_label.text = "LEVEL COMPLETE!"
	color_rect.color = Color(0, 0, 0, 0.7)
	next_button.show()
	show_ui()


func lose() -> void:
	if _game_over:
		return
	_game_over = true
	get_tree().paused = true
	title_label.text = "TRY AGAIN"
	title_label.modulate = Color.INDIAN_RED
	color_rect.color = Color(0, 0, 0, 0.8)
	next_button.hide()
	show_ui()


func show_ui() -> void:
	visible = true


func hide_ui() -> void:
	visible = false
	get_tree().paused = false


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	# TODO


func _on_next_pressed() -> void:
	get_tree().paused = false
	# Soon: we will load the next level from an array
	# For now, just reload the current level to simulate transition
	get_tree().reload_current_scene()

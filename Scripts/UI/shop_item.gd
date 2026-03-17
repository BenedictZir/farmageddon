extends AnimatedButton
class_name ShopItem

## A single item slot in the shop.

@export var item_id: int = 1
@export var item_name: String = "Item Name"
@export var price: int = 10
@export var icon: Texture2D
@export var item_data: Resource  # CropData, or any placeable data
@export var is_goal := false
@export var unlock_level: int = 1

@onready var name_label: Label = $NameLabel
@onready var icon_rect: TextureRect = $IconRect
@onready var price_label: Label = $PriceLabel


func _ready() -> void:
	super()
	
	if is_goal:
		var goal_data = GameManager.get_current_goal_data()
		item_name = goal_data.get("name", "Goal")
		price = goal_data.get("price", 9999)
		icon = goal_data.get("icon", null)
		
	# Apply Locked visual state before initialization so text overriding works
	var is_locked = GameManager.current_level_index < unlock_level
	if is_locked:
		name_label.text = "???"
		price_label.text = "???"
		if icon:
			icon_rect.texture = icon
			icon_rect.modulate = Color(0, 0, 0, 1) # Solid black silhouette
		shrink_to_normal()
		modulate = Color(0.5, 0.5, 0.5, 1.0)
		disabled = true
	else:
		name_label.text = item_name
		price_label.text = str(price) + "g"
		if icon:
			icon_rect.texture = icon
			icon_rect.modulate = Color.WHITE

		CurrencyManager.gold_changed.connect(_on_gold_changed)
		_update_affordability()


func _on_pressed() -> void:
	super()
	if not item_data:
		return
	var player := PlayerRef.instance
	if not player or player.is_carrying:
		return
	if not CurrencyManager.spend_gold(price):
		return
	player.hold_item(item_data)
	if is_goal:
		GameManager.win()


func _on_gold_changed(_new_gold: int) -> void:
	_update_affordability()


func _update_affordability() -> void:
	if GameManager.current_level_index < unlock_level:
		return # Let the _ready pass handle keeping it disabled/dark
		
	var can_afford = CurrencyManager.can_afford(price)
	disabled = not can_afford
	if not can_afford:
		shrink_to_normal()
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_level_index < unlock_level or not CurrencyManager.can_afford(price):
		return
		
	if Input.is_action_just_pressed("shop_" + str(item_id)):
		_press_with_keyboard()
func _press_with_keyboard():
	_on_pressed()
	if _tween:
		await _tween.finished
		shrink_to_normal()

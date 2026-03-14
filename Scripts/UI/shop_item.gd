extends AnimatedButton
class_name ShopItem

## A single item slot in the shop.

@export var item_id: int = 1
@export var item_name: String = "Item Name"
@export var price: int = 10
@export var icon: Texture2D
@export var item_data: Resource  # CropData, or any placeable data

@onready var name_label: Label = $NameLabel
@onready var icon_rect: TextureRect = $IconRect
@onready var price_label: Label = $PriceLabel


func _ready() -> void:
	super()
	name_label.text = item_name
	price_label.text = str(price) + "g"
	if icon:
		icon_rect.texture = icon

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


func _on_gold_changed(_new_gold: int) -> void:
	_update_affordability()


func _update_affordability() -> void:
	var can_afford = CurrencyManager.can_afford(price)
	disabled = not can_afford
	if not can_afford:
		shrink_to_normal()
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("shop_" + str(item_id)):
		_on_pressed()

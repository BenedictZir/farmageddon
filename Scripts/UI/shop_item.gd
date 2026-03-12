extends AnimatedButton
class_name ShopItem

## A single item slot in the shop.
## Inherits Button to get hover/click states easily.

@export var item_id: String = ""
@export var item_name: String = "Item Name"
@export var price: int = 10
@export var icon: Texture2D


@onready var name_label: Label = $NameLabel
@onready var icon_rect: TextureRect = $IconRect
@onready var price_label: Label = $PriceLabel


func _ready() -> void:
	super()  # MUST call — AnimatedButton sets _base_scale, _hover_scale, and connects signals
	name_label.text = item_name
	price_label.text = str(price) + "g"
	if icon:
		icon_rect.texture = icon
	
	# NOTE: mouse_entered/exited/pressed already connected by AnimatedButton._ready()
	CurrencyManager.gold_changed.connect(_on_gold_changed)
	_update_affordability()


func _on_pressed() -> void:
	pass


func _on_gold_changed(_new_gold: int) -> void:
	_update_affordability()


func _update_affordability() -> void:
	# Disable the button if player can't afford it
	var can_afford = CurrencyManager.can_afford(price)
	disabled = not can_afford
	
	# Optional: dim the icon if can't afford
	if not can_afford:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color.WHITE

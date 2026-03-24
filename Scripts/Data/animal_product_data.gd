extends ItemData
class_name AnimalProductData

## Data resource for an animal product (egg, milk, etc.)
## These are harvestable and sellable.


func is_sellable_product() -> bool:
	return true

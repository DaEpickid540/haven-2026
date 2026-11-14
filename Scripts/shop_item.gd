extends HBoxContainer
## One row in the shop (Scenes/shop_item.tscn). Set the exports per item in
## the Inspector: id, name, price and icon. Emits buy_requested when Buy is pressed.
## The shop can update the title/price at runtime (e.g. upgrade levels).

signal buy_requested(item_id: String, price: int)

@export var item_id := "item"
@export var display_name := "Item"
@export var price := 1
@export var icon: Texture2D


func _ready() -> void:
	%Icon.texture = icon
	%Name.text = display_name
	set_price(price)


func set_title(text: String) -> void:
	%Name.text = text


func set_price(new_price: int) -> void:
	price = new_price
	%Price.text = str(price)
	%PriceCoin.show()
	%Buy.text = "Buy"


func set_maxed() -> void:
	%Price.text = ""
	%PriceCoin.hide()
	%Buy.text = "Max"
	%Buy.disabled = true


func set_affordable(affordable: bool) -> void:
	%Buy.disabled = not affordable


func get_buy_button() -> Button:
	return %Buy


func _on_buy_pressed() -> void:
	buy_requested.emit(item_id, price)

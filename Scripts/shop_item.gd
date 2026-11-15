extends HBoxContainer

signal buy_requested(item_id: String)

@export var item_id := "item"
@export var display_name := "Item"
@export var icon: Texture2D

@onready var buy: Button = %Buy


func _ready() -> void:
	%Icon.texture = icon


func refresh() -> void:
	var maxed := PlayerStats.is_maxed(item_id)
	var cost := PlayerStats.get_upgrade_cost(item_id)
	%Name.text = "%s Lv%d" % [display_name, PlayerStats.get_level(item_id)]
	%Price.text = "" if maxed else str(cost)
	%PriceCoin.visible = not maxed
	buy.text = "Max" if maxed else "Buy"
	buy.disabled = maxed or not PlayerStats.can_afford(cost)


func _on_buy_pressed() -> void:
	buy_requested.emit(item_id)

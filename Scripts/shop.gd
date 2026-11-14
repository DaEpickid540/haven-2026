extends CanvasLayer
## Upgrade shop pop-up (Scenes/shop.tscn). Call open() (e.g. when the player
## talks to the shopkeeper); it pauses the game until Close or Esc.
## Each row is a Scenes/shop_item.tscn whose item_id is a PlayerStats upgrade
## ("strength" or "stamina"). Prices and levels come from PlayerStats, so they
## carry over between deaths.

signal purchased(item_id: String)
signal closed

const GREETING := "Get stronger?"
const TOO_POOR := "Not enough coins."
const MAXED := "That's maxed out."

@onready var overlay: Control = %Overlay
@onready var greeting: Label = %Greeting
@onready var coins_label: Label = %Coins
@onready var items: VBoxContainer = %Items


func _ready() -> void:
	overlay.hide()
	for row in items.get_children():
		row.buy_requested.connect(_on_buy_requested)
	PlayerStats.coins_changed.connect(func(_amount): _refresh())
	PlayerStats.upgraded.connect(func(_stat, _level): _refresh())
	_refresh()


func open() -> void:
	if overlay.visible:
		return
	get_tree().paused = true
	greeting.text = GREETING
	_refresh()
	overlay.show()
	_focus_first_available()


func close() -> void:
	if not overlay.visible:
		return
	overlay.hide()
	get_tree().paused = false
	closed.emit()


func is_open() -> bool:
	return overlay.visible


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()  # Don't also open the pause menu.


func _on_buy_requested(stat: String, _price: int) -> void:
	if PlayerStats.is_maxed(stat):
		greeting.text = MAXED
	elif PlayerStats.buy_upgrade(stat):
		greeting.text = "%s is now Lv%d!" % [stat.capitalize(), PlayerStats.get_level(stat)]
		purchased.emit(stat)
	else:
		greeting.text = TOO_POOR
	# A Buy button can become disabled after buying; keep keyboard focus somewhere useful.
	var focused := get_viewport().gui_get_focus_owner()
	if focused is BaseButton and focused.disabled:
		_focus_first_available()


func _refresh() -> void:
	coins_label.text = str(PlayerStats.coins)
	for row in items.get_children():
		var stat: String = row.item_id
		row.set_title("%s Lv%d" % [row.display_name, PlayerStats.get_level(stat)])
		if PlayerStats.is_maxed(stat):
			row.set_maxed()
		else:
			var cost := PlayerStats.get_upgrade_cost(stat)
			row.set_price(cost)
			row.set_affordable(PlayerStats.can_afford(cost))


func _focus_first_available() -> void:
	for row in items.get_children():
		var buy: Button = row.get_buy_button()
		if not buy.disabled:
			buy.grab_focus()
			return
	%Close.grab_focus()

extends CanvasLayer

@onready var overlay: Control = %Overlay
@onready var greeting: Label = %Greeting
@onready var items: VBoxContainer = %Items


func _ready() -> void:
	overlay.hide()
	for row in items.get_children():
		row.buy_requested.connect(_on_buy_requested)
	PlayerStats.coins_changed.connect(_refresh.unbind(1))
	PlayerStats.upgraded.connect(_refresh.unbind(2))
	_refresh()


func open() -> void:
	get_tree().paused = true
	greeting.text = "Get stronger?"
	overlay.show()
	_focus_first_available()


func close() -> void:
	overlay.hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _on_buy_requested(stat: String) -> void:
	if not PlayerStats.buy_upgrade(stat):
		Audio.play_sfx("error")
	else:
		Audio.play_sfx("buy")
		greeting.text = "%s is now Lv%d!" % [stat.capitalize(), PlayerStats.get_level(stat)]
	var focused := get_viewport().gui_get_focus_owner()
	if focused is BaseButton and focused.disabled:
		_focus_first_available()


func _refresh() -> void:
	%Coins.text = str(PlayerStats.coins)
	for row in items.get_children():
		row.refresh()


func _focus_first_available() -> void:
	for row in items.get_children():
		if not row.buy.disabled:
			row.buy.grab_focus()
			return
	%Close.grab_focus()

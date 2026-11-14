extends Node

const PORT := 5512
const PACKET_SIZE := 3
const ACTIONS: Array[StringName] = [
	&"left",
	&"right",
	&"up",
	&"down",
	&"attack",
	&"dash",
	&"interact",
]

class Pad:
	var socket := WebSocketPeer.new()
	var buttons := 0
	var prompt_sent := ""

var _server := TCPServer.new()
var _pads: Array[Pad] = []
var _buttons := 0
var _prompt_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Localhost only; the phone connects through `tailscale serve`.
	var err := _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_warning("Pad server couldn't listen on port %d (error %d)" % [PORT, err])
		set_process(false)


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var pad := Pad.new()
		pad.socket.accept_stream(_server.take_connection())
		_pads.append(pad)
	if _pads.is_empty():
		return

	var prompt := JSON.stringify(_read_prompt())
	for pad: Pad in _pads.duplicate():
		pad.socket.poll()
		match pad.socket.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while pad.socket.get_available_packet_count() > 0:
					var packet := pad.socket.get_packet()
					if pad.socket.was_string_packet():
						_press_prompt_button(packet.get_string_from_utf8())
					elif packet.size() == PACKET_SIZE:
						pad.buttons = packet[0]
						_update_actions()
				if pad.prompt_sent != prompt:
					pad.prompt_sent = prompt
					pad.socket.send_text(prompt)
			WebSocketPeer.STATE_CLOSED:
				_pads.erase(pad)
				_update_actions()


func _update_actions() -> void:
	var held := 0
	for pad in _pads:
		held |= pad.buttons
	for i in ACTIONS.size():
		var pressed := bool(held & (1 << i))
		if pressed != bool(_buttons & (1 << i)):
			var event := InputEventAction.new()
			event.action = ACTIONS[i]
			event.pressed = pressed
			Input.parse_input_event(event)
	_buttons = held


func _read_prompt() -> Variant:
	_prompt_buttons.clear()
	var menu := _focused_menu()
	if menu == null:
		return null

	var title := ""
	for label: Label in menu.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			title = label.text
			break

	var buttons := []
	for button: Button in menu.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			_prompt_buttons.append(button)
			buttons.append({
				"text": _button_text(button),
				"disabled": button.disabled,
			})
	return {"title": title, "buttons": buttons}


func _focused_menu() -> Control:
	var node: Node = get_viewport().gui_get_focus_owner()
	while node != null:
		var control := node as Control
		if control != null and control.anchor_left == 0.0 and control.anchor_top == 0.0 \
				and control.anchor_right == 1.0 and control.anchor_bottom == 1.0:
			return control
		node = node.get_parent()
	return null


func _button_text(button: Button) -> String:
	if not button.get_parent() is HBoxContainer:
		return button.text
	var row := PackedStringArray()
	for sibling in button.get_parent().get_children():
		if sibling is Label and sibling.visible and sibling.text != "":
			row.append(sibling.text)
	return "%s: %s" % [" ".join(row), button.text]


func _press_prompt_button(index_text: String) -> void:
	if not index_text.is_valid_int():
		return
	_read_prompt()
	var index := index_text.to_int()
	if index < 0 or index >= _prompt_buttons.size() or _prompt_buttons[index].disabled:
		return
	var button := _prompt_buttons[index]
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	else:
		button.pressed.emit()

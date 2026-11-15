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
	&"pause",
]

class Pad:
	var socket := WebSocketPeer.new()
	var buttons := 0
	var prompt_sent := ""

var _server := TCPServer.new()
var _pads: Array[Pad] = []
var _buttons := 0
var _prompt_buttons: Array[Button] = []
var _web_link: JavaScriptObject = null
var _web_buttons := 0
var _web_prompt := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		return
	var err := _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_warning("Pad server couldn't listen on port %d (error %d)" % [PORT, err])
		set_process(false)


func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		_poll_web()
		return
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
	var held := _web_buttons
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

	var lines := []
	for label: Label in menu.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and not label.get_parent() is HBoxContainer:
			lines.append(_label_data(label))

	var buttons := []
	for button: Button in menu.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			_prompt_buttons.append(button)
			buttons.append({
				"text": button.text,
				"labels": _row_labels(button),
				"width": button.size.x,
				"disabled": button.disabled,
				"focused": button.has_focus(),
			})

	var panel_size := Vector2.ZERO
	for panel: Control in menu.find_children("*", "PanelContainer", true, false):
		if panel.is_visible_in_tree():
			panel_size = panel.size
			break

	return {
		"panel": panel_size != Vector2.ZERO,
		"width": panel_size.x,
		"height": panel_size.y,
		"lines": lines,
		"buttons": buttons,
	}


func _label_data(label: Label) -> Dictionary:
	return {
		"text": label.text,
		"style": String(label.theme_type_variation),
	}


func _focused_menu() -> Control:
	var node: Node = get_viewport().gui_get_focus_owner()
	while node != null:
		var control := node as Control
		if control != null and control.anchor_left == 0.0 and control.anchor_top == 0.0 \
				and control.anchor_right == 1.0 and control.anchor_bottom == 1.0:
			return control
		node = node.get_parent()
	return null


func _row_labels(button: Button) -> Array:
	var labels := []
	if button.get_parent() is HBoxContainer:
		for sibling in button.get_parent().get_children():
			if sibling is Label and sibling.visible and sibling.text != "":
				labels.append(_label_data(sibling))
	return labels


func _press_prompt_button(index_text: String) -> void:
	if not index_text.is_valid_int():
		return
	_read_prompt()
	var index := index_text.to_int()
	if index < 0 or index >= _prompt_buttons.size() or _prompt_buttons[index].disabled:
		return
	var button := _prompt_buttons[index]
	button.grab_focus()
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	else:
		button.pressed.emit()


# web

func _poll_web() -> void:
	if _web_link == null:
		_web_link = JavaScriptBridge.get_interface("padLink")
		if _web_link == null:
			return
	if not _web_link.connected:
		_web_prompt = ""
		if _web_buttons != 0:
			_web_buttons = 0
			_update_actions()
		return

	var buttons := int(_web_link.buttons)
	if buttons != _web_buttons:
		_web_buttons = buttons
		_update_actions()

	var choice := str(_web_link.takeChoice())
	while choice != "":
		_press_prompt_button(choice)
		choice = str(_web_link.takeChoice())

	var prompt := JSON.stringify(_read_prompt())
	if prompt != _web_prompt:
		_web_prompt = prompt
		_web_link.sendPrompt(prompt)

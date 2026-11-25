extends Node

const PORT := 5512
const PACKET_SIZE := 3
const ACTIONS: Array[StringName] = [
	&"left",
	&"right",
	&"up",
	&"down",
	&"attack",
	&"sprint",
	&"interact",
	&"pause",
	&"dash",
]

class Pad:
	var socket := WebSocketPeer.new()
	var buttons := 0
	var prompt_sent := ""

var _server := TCPServer.new()
var _pads: Array[Pad] = []
var _buttons := 0
var _prompt_buttons: Array[Control] = []
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
					elif packet.size() >= PACKET_SIZE:
						pad.buttons = packet[0]
						if packet.size() > PACKET_SIZE:
							pad.buttons |= packet[PACKET_SIZE] << 8
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
	var buttons := []
	for node in menu.find_children("*", "", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var parent := control.get_parent()
		if control is GridContainer:
			lines.append(_grid_data(control))
		elif control is Label and not parent is HBoxContainer and not parent is GridContainer:
			lines.append(_label_data(control))
		elif control is Button or control is Slider:
			_prompt_buttons.append(control)
			buttons.append(_item_data(control))

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


func _grid_data(grid: GridContainer) -> Dictionary:
	var cells := []
	for child in grid.get_children():
		var label := child as Label
		if label != null and label.visible:
			var data := _label_data(label)
			data["align"] = label.horizontal_alignment
			cells.append(data)
	return {
		"columns": grid.columns,
		"cells": cells,
		"h_gap": grid.get_theme_constant("h_separation"),
		"v_gap": grid.get_theme_constant("v_separation"),
	}


func _item_data(control: Control) -> Dictionary:
	var labels := _row_labels(control)
	var data := {
		"labels": labels,
		"split": _labels_before(control, labels.size()),
		"group": _button_group(control, labels),
		"width": control.size.x,
		"focused": control.has_focus(),
	}
	var slider := control as Slider
	if slider != null:
		data["text"] = ""
		data["slider"] = inverse_lerp(slider.min_value, slider.max_value, slider.value)
		data["disabled"] = not slider.editable
	else:
		data["text"] = (control as Button).text
		data["disabled"] = (control as Button).disabled
	return data


func _row_labels(control: Control) -> Array:
	var labels := []
	if control.get_parent() is HBoxContainer:
		for sibling in control.get_parent().get_children():
			if sibling is Label and sibling.visible and sibling.text != "":
				labels.append(_label_data(sibling))
	return labels


func _labels_before(control: Control, total: int) -> int:
	if total == 0:
		return 0
	var count := 0
	for sibling in control.get_parent().get_children():
		if sibling == control:
			return count
		if sibling is Label and sibling.visible and sibling.text != "":
			count += 1
	return total


# side-by-side
func _button_group(control: Control, labels: Array) -> String:
	var parent := control.get_parent()
	if parent is HBoxContainer and labels.is_empty():
		return str(parent.get_instance_id())
	return ""


func _press_prompt_button(choice: String) -> void:
	var parts := choice.split(":")
	if not parts[0].is_valid_int():
		return
	_read_prompt()
	var index := parts[0].to_int()
	if index < 0 or index >= _prompt_buttons.size():
		return
	var slider := _prompt_buttons[index] as Slider
	if slider != null:
		if slider.editable and parts.size() == 2:
			slider.grab_focus()
			var nudge := maxf(slider.step, (slider.max_value - slider.min_value) / 10.0)
			slider.value += nudge * (-1.0 if parts[1] == "-" else 1.0)
		return
	var button := _prompt_buttons[index] as Button
	if button.disabled:
		return
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

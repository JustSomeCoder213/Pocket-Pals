class_name GameMenu
extends CanvasLayer

## Esc menu: Resume, Save now, Open save folder, Sound on/off, Reset progress, Quit.
## Reset needs two clicks within 4 seconds, so it can't happen by accident.

signal closed
signal save_requested
signal reset_requested
signal quit_requested

const RESET_CONFIRM_MS := 4000

var _status_label: Label
var _sound_button: Button
var _reset_button: Button
var _reset_armed_until := 0  # Time.get_ticks_msec() deadline, 0 = not armed


func _ready() -> void:
	_build_ui()
	visible = false


func open() -> void:
	_disarm_reset()
	_status_label.text = ""
	_update_sound_button()
	visible = true


## Feedback line shown inside the menu ("Game saved at 14:03:22.").
func set_status(text: String) -> void:
	_status_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _process(_delta: float) -> void:
	if _reset_armed_until > 0 and Time.get_ticks_msec() > _reset_armed_until:
		_disarm_reset()


func _close() -> void:
	_disarm_reset()
	visible = false
	closed.emit()


# ---------- Buttons ----------

func _on_open_folder_pressed() -> void:
	OS.shell_open(SaveManager.get_save_folder())


func _on_sound_pressed() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_update_sound_button()


func _on_reset_pressed() -> void:
	if _reset_armed_until > 0:
		_disarm_reset()
		visible = false
		reset_requested.emit()
		return
	_reset_armed_until = Time.get_ticks_msec() + RESET_CONFIRM_MS
	_reset_button.text = "Click again to ERASE everything"
	_reset_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))


func _disarm_reset() -> void:
	_reset_armed_until = 0
	_reset_button.text = "Reset progress..."
	_reset_button.remove_theme_color_override("font_color")


func _update_sound_button() -> void:
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_sound_button.text = "Sound: Off" if muted else "Sound: On"


# ---------- UI construction ----------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var info := Label.new()
	info.text = "Your progress saves automatically every 30 seconds and after photos, purchases and discoveries.\nSave folder:\n%s" % SaveManager.get_save_folder()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(470, 0)
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	column.add_child(info)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(470, 26)
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	column.add_child(_status_label)

	_make_button(column, "Resume (Esc)", _close)
	_make_button(column, "Save game now", func() -> void: save_requested.emit())
	_make_button(column, "Open save folder", _on_open_folder_pressed)
	_sound_button = _make_button(column, "Sound: On", _on_sound_pressed)
	_reset_button = _make_button(column, "Reset progress...", _on_reset_pressed)
	_make_button(column, "Save and quit game", func() -> void: quit_requested.emit())


func _make_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

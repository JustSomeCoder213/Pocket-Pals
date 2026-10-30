extends CanvasLayer

## Modal "photo result" panel. A dark full-screen rectangle swallows mouse clicks
## so nothing behind the panel can be pressed while it is open.

signal closed

var _species_label: Label
var _new_label: Label
var _score_label: Label
var _rating_label: Label
var _coins_label: Label
var _breakdown_grid: GridContainer


func _ready() -> void:
	_build_ui()
	visible = false


func show_result(result: Dictionary) -> void:
	_species_label.text = "%s  (%s)" % [result["species_name"], result["pose_name"]]
	var bonus := int(result.get("discovery_bonus", 0))
	_new_label.visible = bool(result["is_new_discovery"])
	_new_label.text = "NEW DISCOVERY!  (+%d bonus coins)" % bonus
	_score_label.text = "%d / 100" % int(result["score"])
	_rating_label.text = str(result["rating"])
	_coins_label.text = "+%d coins" % int(result["coins"])
	if bonus > 0:
		_coins_label.text += "  (incl. %d bonus)" % bonus

	for child in _breakdown_grid.get_children():
		_breakdown_grid.remove_child(child)
		child.queue_free()
	for row in result["breakdown"]:
		var name_label := Label.new()
		name_label.text = str(row["label"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_breakdown_grid.add_child(name_label)
		var points_label := Label.new()
		points_label.text = "%.1f / %.0f" % [float(row["points"]), float(row["max"])]
		points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_breakdown_grid.add_child(points_label)

	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	visible = false
	closed.emit()


# ---------- UI construction ----------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "ResultPanel"
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := _make_label(column, "PHOTO RESULT", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	_species_label = _make_label(column, "", 28)
	_new_label = _make_label(column, "NEW DISCOVERY!", 22)
	_new_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_new_label.visible = false
	_score_label = _make_label(column, "", 52)
	_rating_label = _make_label(column, "", 20)

	column.add_child(HSeparator.new())
	_breakdown_grid = GridContainer.new()
	_breakdown_grid.name = "BreakdownGrid"
	_breakdown_grid.columns = 2
	_breakdown_grid.add_theme_constant_override("h_separation", 40)
	column.add_child(_breakdown_grid)
	column.add_child(HSeparator.new())

	_coins_label = _make_label(column, "", 30)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	var close_button := Button.new()
	close_button.text = "Close (Enter)"
	close_button.custom_minimum_size = Vector2(0, 48)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close)
	column.add_child(close_button)


func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

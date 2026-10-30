class_name CollectionScreen
extends CanvasLayer

## Collection overlay. A dim full-screen rectangle blocks clicks behind it.
## Closes with the Close button, Esc, or J. It rebuilds its cards whenever it opens
## (and whenever the collection changes while it is open).

signal closed

const RARITY_COLORS := {
	"Common": Color(0.85, 0.88, 0.92),
	"Uncommon": Color(0.55, 1.0, 0.65),
	"Rare": Color(1.0, 0.85, 0.3),
}
const COLOR_GOLD := Color(1.0, 0.85, 0.3)

var _discovery: DiscoverySystem
var _summary_label: Label
var _grid: GridContainer


func _ready() -> void:
	_build_ui()
	visible = false


## Called by main.gd after the screen is in the tree.
func setup(discovery: DiscoverySystem) -> void:
	_discovery = discovery
	discovery.changed.connect(_on_discovery_changed)


func open() -> void:
	_rebuild()
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_collection"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	visible = false
	closed.emit()


func _on_discovery_changed() -> void:
	if visible:
		_rebuild()


# ---------- Cards ----------

func _rebuild() -> void:
	if _discovery == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var all_species := SpeciesDatabase.get_all()
	_summary_label.text = "Discovered %d / %d" % [_discovery.get_discovered_count(), all_species.size()]
	for species in all_species:
		_grid.add_child(_make_card(species))


func _make_card(species: CreatureSpecies) -> Control:
	var found := _discovery.is_discovered(str(species.species_id))

	var card := PanelContainer.new()
	card.name = "Card_%s" % species.species_id
	card.custom_minimum_size = Vector2(390, 150)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	# Portrait: a colored circle when discovered, a dark silhouette with "?" when not.
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(88, 88)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.set_border_width_all(4)
	style.set_corner_radius_all(44)
	if found:
		style.bg_color = species.body_color
		style.border_color = species.accent_color
	else:
		style.bg_color = Color(0.1, 0.1, 0.14)
		style.border_color = Color(0.3, 0.3, 0.4)
	portrait.add_theme_stylebox_override("panel", style)
	var face := Label.new()
	face.text = "(^_^)" if found else "?"
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_theme_font_size_override("font_size", 20 if found else 44)
	face.add_theme_color_override("font_color", Color(0.25, 0.12, 0.18) if found else Color(0.4, 0.4, 0.5))
	portrait.add_child(face)
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var name_label := _make_label(info, species.display_name if found else "???", 22)

	var meta_label := _make_label(info, "", 16)
	if found:
		meta_label.text = "%s   |   Habitat: %s" % [species.rarity, species.habitat]
		meta_label.add_theme_color_override("font_color", RARITY_COLORS.get(species.rarity, Color.WHITE))
	else:
		meta_label.text = "Rarity: ???   |   Habitat: %s" % species.habitat
		meta_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

	var description := _make_label(info, "", 15)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(250, 0)
	if found:
		description.text = species.description
	else:
		description.text = "Not discovered yet. Find it and take its photo!"
		description.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

	if found:
		var record := _discovery.get_record(str(species.species_id))
		var best := _make_label(info, "", 15)
		if int(record["photos"]) > 0:
			best.text = "Best photo: %d   |   Photos taken: %d" % [int(record["best_score"]), int(record["photos"])]
		else:
			best.text = "No photos yet"
		best.add_theme_color_override("font_color", COLOR_GOLD)
	return card


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
	panel.name = "CollectionPanel"
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "COLLECTION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 22)
	_summary_label.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(_summary_label)

	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(820, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	var close_button := Button.new()
	close_button.text = "Close (J / Esc)"
	close_button.custom_minimum_size = Vector2(0, 46)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close)
	column.add_child(close_button)


func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

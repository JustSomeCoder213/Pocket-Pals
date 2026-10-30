extends Node

## Global game state shared by every scene.
## Registered as an autoload named "GameManager".

enum Mode { INTRO, HOME, CAMERA, OUTDOOR }

signal mode_changed(new_mode: Mode)
signal coins_changed(new_amount: int)

## Keyboard actions registered at startup (action name -> key).
const ACTION_KEYS := {
	"toggle_camera": KEY_C,
	"take_photo": KEY_SPACE,
	"go_home": KEY_H,
	"go_outdoor": KEY_O,
	"open_shop": KEY_B,
	"open_collection": KEY_J,
	"confirm": KEY_ENTER,
}

var current_mode: Mode = Mode.HOME
var coins: int = 0:
	set = set_coins


func _ready() -> void:
	_register_input_actions()


func set_mode(new_mode: Mode) -> void:
	if new_mode == current_mode:
		return
	current_mode = new_mode
	mode_changed.emit(current_mode)


func set_coins(value: int) -> void:
	coins = maxi(value, 0)  # coins can never go negative
	coins_changed.emit(coins)


func add_coins(amount: int) -> void:
	set_coins(coins + amount)


func _register_input_actions() -> void:
	for action_name in ACTION_KEYS:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = ACTION_KEYS[action_name] as Key
		InputMap.action_add_event(action_name, event)

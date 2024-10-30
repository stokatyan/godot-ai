extends Node2D

class_name CombatUnitUI

enum UIState {
	basic,
	showing_move_range
}

enum UIEvent {
	left_click,
}

@export var block: Node2D


var _combat_unit_node_uuid: int
var _current_ui_state: UIState = UIState.basic

var game_delegate: Game

var _movement_range: float

var _battle_delegate_ref: WeakRef
var _battle_delegate: BattleSimulation:
	get:
		if _battle_delegate_ref:
			return _battle_delegate_ref.get_ref()
		return null

var combat_unit_node: CombatUnitNode:
	get:
		if !_battle_delegate:
			return null
		return _battle_delegate.get_combat_unit(_combat_unit_node_uuid)

var _army_colors = {
	CombatUnitNode.Army.blue: Color("7b9494"),
	CombatUnitNode.Army.red: Color("947b7b")
}

func _draw():
	if _current_ui_state == UIState.showing_move_range:
		draw_circle(Vector2.ZERO, _movement_range, Color(1, 1, 1, 0.2), false, 2, true)
	else:
		return

func set_node(unit: CombatUnitNode, battle_delegate: BattleSimulation):
	_combat_unit_node_uuid = unit._uuid
	_movement_range = unit.movement_range
	_battle_delegate_ref = weakref(battle_delegate)

func refresh():
	var unit_node = combat_unit_node
	global_position = unit_node.position
	rotation = unit_node.rotation
	block.modulate = _army_colors[unit_node._army] as Color
	block.modulate.a = float(unit_node._health + 1) / float(unit_node._max_health + 1)

func _show_movement_range():
	_current_ui_state = UIState.showing_move_range

func _hide_movement_range():
	_current_ui_state = UIState.basic

func _on_area_2d_input_event(_viewport, event, _shape_idx):
	var mouse_button_event = event as InputEventMouseButton
	if mouse_button_event and mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button_event.is_pressed() and !mouse_button_event.is_echo():
			_handle_left_click()

func _handle_left_click():
	match _current_ui_state:
		UIState.basic:
			_show_movement_range()
		UIState.showing_move_range:
			_hide_movement_range()

	game_delegate.did_select_combat_unit_ui(self)
	queue_redraw()

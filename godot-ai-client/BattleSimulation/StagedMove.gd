extends RefCounted

class_name StagedMove

var combat_unit_uuid: int
var start_position: Vector2
var end_position: Vector2
var start_rotation: float
var end_rotation: float

func _init(_combat_unit_uuid: int, _start_position: Vector2, _end_position: Vector2, _start_rotation: float, _end_rotation: float):
	combat_unit_uuid =_combat_unit_uuid
	start_position = _start_position
	end_position = _end_position
	start_rotation = _start_rotation
	end_rotation = _end_rotation

extends RefCounted

class_name CombatUnitNode

static var _max_uuid: int = 1

enum Unit {
	infantry
}

enum Army {
	blue,
	red
}

var _delegate: WeakRef
var _battle_delegate: BattleSimulation:
	get:
		if _delegate:
			return _delegate.get_ref()
		return null

var _uuid: int = -1

var _unit: Unit
var _army: Army

var other_army: Army:
	get:
		return ((_army + 1) % 2) as Army

var position: Vector2
var rotation: float

var movement_range: float:
	get:
		match _unit:
			Unit.infantry:
				return 150
		return 0

var vision_range: float:
	get:
		match _unit:
			Unit.infantry:
				return 1000
		return 0

var _health = 3
var _max_health: int:
	get:
		return 3

var _is_obsolete: bool:
	get:
		return _health <= 0

func _init(a: Army, u: Unit, delegate: BattleSimulation):
	_max_uuid += 1
	_uuid = _max_uuid

	_army = a
	_unit = u
	_delegate = weakref(delegate)


func duplicate(delegate: BattleSimulation) -> CombatUnitNode:
	var new: CombatUnitNode = CombatUnitNode.new(self._army, self._unit, delegate)

	new._uuid = _uuid
	new._health = _health
	new.position = position
	_delegate = weakref(delegate)

	return new

func engaged_by(_enemy_unit: CombatUnitNode):
	_health -= 1
	if _health <= 0:
		_health = 0

func apply_move(move: StagedMove):
	position = move.end_position
	rotation = move.end_rotation

func get_rotation_to(to_position: Vector2) -> float:
	return (to_position - position).angle()

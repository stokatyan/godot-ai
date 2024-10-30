extends RefCounted

class_name BattleSimulation

var _combat_unit_uuids_to_units = {}

var _combat_unit_uuids_to_staged_moves = {}

var _min_required_distance: float = 50
var _min_required_distance_squared: float = 2500
var _padding_when_adjusting_for_overlap: float = 5

func duplicate() -> BattleSimulation:
	var dup = BattleSimulation.new()
	for key in _combat_unit_uuids_to_units.keys():
		var unit: CombatUnitNode = _combat_unit_uuids_to_units[key]
		dup._combat_unit_uuids_to_units[key] = unit.duplicate(self)

	return dup

func add_combat_unit(unit: CombatUnitNode):
	_combat_unit_uuids_to_units[unit._uuid] = unit

func commit_moves():
	for k in _combat_unit_uuids_to_staged_moves.keys():
		var move = _combat_unit_uuids_to_staged_moves[k]
		var combat_unit = get_combat_unit(move.combat_unit_uuid)
		combat_unit.apply_move(move)
	_combat_unit_uuids_to_staged_moves.clear()

func stage_move(unit_uuid: int, target: Vector2):
	if !_combat_unit_uuids_to_units.has(unit_uuid):
		return
	var combat_unit: CombatUnitNode = _combat_unit_uuids_to_units[unit_uuid]

	var delta = (target - combat_unit.position)
	var length = delta.length()
	var direction = delta.normalized()
	var adjusted_target = target
	if length > combat_unit.movement_range:
		adjusted_target = (direction * combat_unit.movement_range) + combat_unit.position

	for k in _combat_unit_uuids_to_units.keys():
		var other_unit: CombatUnitNode = _combat_unit_uuids_to_units[k]
		if other_unit._uuid == combat_unit._uuid:
			continue

		if _will_overlap(combat_unit.position, adjusted_target, other_unit.position, _min_required_distance):
			var direction_to_unit = combat_unit.position - other_unit.position
			direction_to_unit = direction_to_unit.normalized()
			direction_to_unit *= (_min_required_distance + _padding_when_adjusting_for_overlap)
			adjusted_target = other_unit.position + direction_to_unit

	var new_staged_move = StagedMove.new(
		unit_uuid,
		combat_unit.position,
		adjusted_target,
		combat_unit.rotation,
		combat_unit.rotation
	)

	if _combat_unit_uuids_to_staged_moves.has(combat_unit._uuid):
		var pending_move: StagedMove = _combat_unit_uuids_to_staged_moves[combat_unit._uuid]
		new_staged_move.end_rotation = pending_move.end_rotation

	_combat_unit_uuids_to_staged_moves[combat_unit._uuid] = new_staged_move

func stage_move_using_direction_and_magnitude(unit_uuid: int, direction_angle: float, magnitude: float):
	if !_combat_unit_uuids_to_units.has(unit_uuid):
		return
	var combat_unit: CombatUnitNode = _combat_unit_uuids_to_units[unit_uuid]

	var target: Vector2 = Vector2(1, 0)

	target = target.rotated(direction_angle)

	target *= magnitude
	target += combat_unit.position

	stage_move(unit_uuid, target)

func stage_rotate(unit_uuid: int, target: float):
	if !_combat_unit_uuids_to_units.has(unit_uuid):
		return

	var combat_unit: CombatUnitNode = _combat_unit_uuids_to_units[unit_uuid]
	var new_staged_move = StagedMove.new(
		unit_uuid,
		combat_unit.position,
		combat_unit.position,
		combat_unit.rotation,
		target
	)

	if _combat_unit_uuids_to_staged_moves.has(combat_unit._uuid):
		var pending_move: StagedMove = _combat_unit_uuids_to_staged_moves[combat_unit._uuid]
		new_staged_move.end_position = pending_move.end_position

	_combat_unit_uuids_to_staged_moves[combat_unit._uuid] = new_staged_move

func get_army(type: CombatUnitNode.Army) -> Array[CombatUnitNode]:
	var units: Array[CombatUnitNode] = []
	for k in _combat_unit_uuids_to_units.keys():
		var unit: CombatUnitNode = _combat_unit_uuids_to_units[k]
		if unit._army == type:
			units.append(unit)

	return units

func get_combat_unit(uuid: int) -> CombatUnitNode:
	if _combat_unit_uuids_to_units.has(uuid):
		return _combat_unit_uuids_to_units[uuid]
	return null

func get_normalized_distances_to_army_in_vision_range(unit: CombatUnitNode, army: CombatUnitNode.Army) -> Array[float]:
	var angles_to_distances: Array[float] = []
	for i in range(6):
		angles_to_distances.append(unit.vision_range)

	var atom = 2 * PI / 12

	for u in get_army(army):
		var other_unit: CombatUnitNode = u
		if other_unit._uuid == unit._uuid:
			continue
		var rotation = unit.get_rotation_to(other_unit.position)
		var distance = unit.position.distance_to(other_unit.position)
		if abs(rotation) < atom:
			angles_to_distances[0] = min(angles_to_distances[0], distance)
		elif rotation < 3 * atom:
			angles_to_distances[1] = min(angles_to_distances[0], distance)
		elif rotation < 5 * atom:
			angles_to_distances[2] = min(angles_to_distances[0], distance)
		elif rotation < 7 * atom:
			angles_to_distances[3] = min(angles_to_distances[0], distance)
		elif rotation < 9 * atom:
			angles_to_distances[4] = min(angles_to_distances[0], distance)
		elif rotation < 11 * atom:
			angles_to_distances[5] = min(angles_to_distances[0], distance)

	for i in range(6):
		angles_to_distances[i] = angles_to_distances[i] / unit.vision_range

	return angles_to_distances

func get_battle_input_vector_for_unit(unit: CombatUnitNode) -> Array[float]:
	var input_vector: Array[float] = []
	var enemy_inputs: Array[float] = get_normalized_distances_to_army_in_vision_range(unit, unit.other_army)

	for input in enemy_inputs:
		input_vector.append(input)

	return input_vector

func _will_overlap(p1: Vector2, p3: Vector2, p2: Vector2, r: float) -> bool:
	var min_distance = 2 * r

	# Vector from p1 to p3
	var p1_to_p3 = p3 - p1
	# Vector from p1 to p2
	var p1_to_p2 = p2 - p1

	# Project p1_to_p2 onto p1_to_p3
	var projection = p1_to_p2.dot(p1_to_p3) / p1_to_p3.length_squared()
	var closest_point: Vector2

	# Determine the closest point on the line segment to p2
	if projection < 0.0:
		return false
		#closest_point = p1  # Closest to p1 if the projection is negative
	elif projection > 1.0:
		closest_point = p3  # Closest to p3 if the projection exceeds 1
	else:
		closest_point = p1 + p1_to_p3 * projection  # Closest point on the segment

	# Calculate the distance from p2 to the closest point
	var distance_to_p2 = (closest_point - p2).length()

	# Check if this distance is less than the required distance
	return distance_to_p2 < min_distance

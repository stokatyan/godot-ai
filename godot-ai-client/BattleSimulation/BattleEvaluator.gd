extends RefCounted

class_name BattleEvaluator

func evaluate(battle: BattleSimulation, army: CombatUnitNode.Army) -> float:
	var enemy_army = _get_other_army(army)

	var army_units = battle.get_army(army)
	var enemy_army_units = battle.get_army(enemy_army)

	if enemy_army_units.is_empty():
		return 10000

	var evaluation = 0
	evaluation += _distance_evaluation(army_units, enemy_army_units)
	#evaluation += _health_evaluation(army_units, enemy_army_units) * 10
	if evaluation >= -300:
		evaluation = (300 - abs(evaluation)) * 3

	evaluation = (evaluation / 650.0) * 2
	return evaluation * abs(evaluation)

func _get_other_army(army: CombatUnitNode.Army) -> CombatUnitNode.Army:
	if army == CombatUnitNode.Army.red:
		return CombatUnitNode.Army.blue
	return CombatUnitNode.Army.red

func _health_evaluation(army: Array[CombatUnitNode], enemy_army: Array[CombatUnitNode]) -> float:
	var army_health = _get_army_health(army)
	var enemy_health = _get_army_health(enemy_army)

	return -enemy_health# + army_health / (enemy_health + 1)

	#var diff = army_health - enemy_health
	#return diff * 5 / enemy_health - enemy_health

func _distance_evaluation(army: Array[CombatUnitNode], enemy_army: Array[CombatUnitNode]) -> float:
	var army_mean_position = _get_mean_position(army)
	var enemy_army_mean_position = _get_mean_position(enemy_army)

	var diff = army_mean_position.distance_to(enemy_army_mean_position)

	if army.size() >= enemy_army.size():
		diff *= -1

	return diff

func _get_mean_position(army: Array[CombatUnitNode]) -> Vector2:
	var mean_position = Vector2.ZERO
	for unit in army:
		if !unit._is_obsolete:
			mean_position += unit.position
	if !army.is_empty():
		mean_position /= army.size()
	return mean_position

func _get_army_health(army: Array[CombatUnitNode]) -> float:
	var sum: float = 0
	for unit in army:
		sum += unit._health

	return sum

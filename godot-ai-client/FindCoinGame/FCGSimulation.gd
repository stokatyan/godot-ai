extends BaseSimulation

class_name FCGSimulation

var _hero: FCGHero = FCGHero.new()
var _target: FCGTarget = FCGTarget.new()

var _map_size: float = 1000

func new_game():
	var r1 = randf_range(0, _map_size) - _map_size/2.0
	var r2 = randf_range(0, _map_size) - _map_size/2.0
	_hero._position = Vector2(r1, r2)
	_hero._rotation = randf_range(0, 2 * PI)

	var r3 = randf_range(0, _map_size) - _map_size/2.0
	var r4 = randf_range(0, _map_size) - _map_size/2.0
	_target._position = Vector2(r3, r4)
	if is_game_complete():
		new_game()

func is_game_complete() -> bool:
	return _hero._position.distance_to(_target._position) < _hero._radius + _target._radius

func apply_action(action_vector: Array[float], callback):
	_hero.move(action_vector[0], action_vector[1])
	if callback:
		callback.call()

func get_game_state() -> Array[float]:
	return [_hero._position.x, _hero._position.y, _hero._rotation] + _hero.get_vision_angles()

func get_score() -> float:
	if is_game_complete():
		return 100
	return 0

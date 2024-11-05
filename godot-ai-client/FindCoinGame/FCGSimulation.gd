extends BaseSimulation

class_name FCGSimulation

var _hero: FCGHero = FCGHero.new()
var _target: FCGTarget = FCGTarget.new()

var _map_size: float = 1000
var _map_radius: float:
	get:
		return _map_size/2

var _actions_taken = 0

func new_game():
	_actions_taken = 0
	var r1 = randf_range(0, _map_size) - _map_radius
	var r2 = randf_range(0, _map_size) - _map_radius
	_hero._position = Vector2(r1, r2)
	_hero._rotation = randf_range(0, 2 * PI)

	var r3 = randf_range(0, _map_size) - _map_radius
	var r4 = randf_range(0, _map_size) - _map_radius
	_target._position = Vector2(r3, r4)
	if is_game_complete():
		new_game()

func is_game_complete() -> bool:
	return _hero._position.distance_to(_target._position) < _hero._radius + _target._radius

func apply_action(action_vector: Array[float], callback):
	_actions_taken += 1
	_hero.move(action_vector[0], action_vector[1])
	if callback:
		callback.call(self)

func get_game_state() -> Array[float]:
	var angles = _hero.get_vision_angles()
	var state: Array[float] = [
		_hero._position.x / 2.0 - _map_radius,
		_hero._position.y / 2.0 - _map_radius,
		_hero._rotation / (2 * PI)
	]
	for a in angles:
		var vision_unit = Vector2.from_angle(a)
		var vision_vector = vision_unit * _hero.max_vision_distance
		var distance = _hero.max_vision_distance
		var overlap_point = _will_overlap(
			_hero._position,
			_hero._position + vision_vector,
			_target._position,
			_target._radius + _hero._radius
		)
		if overlap_point:
			distance = _hero._position.distance_to(overlap_point)
		distance /= _hero.max_vision_distance # bound to range of 0 -> 1
		state.append(distance)

	return state

func get_score() -> float:
	if is_game_complete():
		return 200 - _actions_taken * 2
	return 0

func rescore_history(history: Array[Replay]):
	if history.is_empty():
		return
	var final_reward = history[history.size() - 1].reward
	for i in range(history.size()):
		var rescore_scalar = float(i + 1.0) / float(history.size())
		history[i].reward = final_reward * rescore_scalar

func create_hindsight_replays(history: Array[Replay]) -> Array[Replay]:
	var hindsight_replays: Array[Replay] = []
	if history.size() < 2:
		return hindsight_replays

	var final_hero_state: Array[float] = history[history.size() - 1].state_
	var final_hero_position: Vector2 = Vector2(
		(final_hero_state[0] + _map_radius) * 2.0,
		(final_hero_state[1] + _map_radius) * 2.0,
	)
	var initial_hero_state: Array[float] = history[0].state_
	var initial_hero_position: Vector2 = Vector2(
		(initial_hero_state[0] + _map_radius) * 2.0,
		(initial_hero_state[1] + _map_radius) * 2.0,
	)
	var initial_hero_rotation = initial_hero_state[2] * 2 * PI

	_target._position = final_hero_position
	_hero._position = initial_hero_position
	_hero._rotation = initial_hero_rotation
	for replay in history:
		var state = get_game_state()
		var action = replay.action
		apply_action(action, null)
		var reward = get_score()
		var is_done = is_game_complete()
		var new_replay = Replay.new(state, action, reward, get_game_state(), is_done)
		hindsight_replays.append(new_replay)
		if is_done:
			rescore_history(hindsight_replays)
			break

	return hindsight_replays

## Check if p2 will overlap the line from p1 to p3
func _will_overlap(p1: Vector2, p3: Vector2, p2: Vector2, r: float):
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
		#return null
		closest_point = p1  # Closest to p1 if the projection is negative
	elif projection > 1.0:
		closest_point = p3  # Closest to p3 if the projection exceeds 1
	else:
		closest_point = p1 + p1_to_p3 * projection  # Closest point on the segment

	# Calculate the distance from p2 to the closest point
	var distance_to_p2 = (closest_point - p2).length()

	if distance_to_p2 < min_distance:
		return closest_point

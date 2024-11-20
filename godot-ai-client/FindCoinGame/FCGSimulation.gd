extends BaseSimulation

class_name FCGSimulation

var _hero: FCGHero = FCGHero.new()
var _target: FCGTarget = FCGTarget.new()

var _map_size: float = 600
var _map_radius: float:
	get:
		return _map_size/2

var _actions_taken = 0

var _prev_action: Array[float] = [0.0, 0.0]
var _prev_observation: Array[float] = []
var _initial_hero_position: Vector2

var _wall_thickness: float = 5

var _physics_space: RID
var _wall_bodies: Array[RID] = []

var _target_layer = 0b0010
var _hero_layer = 0b0001

func _init():
	_setup_physics_server()
	new_game()

func _setup_physics_server():
	_physics_space = PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(_physics_space, true)

	PhysicsServer2D.body_set_space(_hero._physics_body, _physics_space)
	PhysicsServer2D.body_set_collision_layer(_hero._physics_body, _hero_layer)
	PhysicsServer2D.body_set_collision_mask(_hero._physics_body, _hero_layer)

	PhysicsServer2D.body_set_space(_target._physics_body, _physics_space)
	PhysicsServer2D.body_set_collision_layer(_target._physics_body, _target_layer)
	PhysicsServer2D.body_set_collision_mask(_target._physics_body, _target_layer)

	var wall_segments: Array[Rect2] = [
		Rect2(Vector2(-_map_radius, _map_radius), Vector2(_map_radius, _map_radius)),
		Rect2(Vector2(_map_radius, _map_radius), Vector2(_map_radius, -_map_radius)),
		Rect2(Vector2(_map_radius, -_map_radius), Vector2(-_map_radius, -_map_radius)),
		Rect2(Vector2(-_map_radius, -_map_radius), Vector2(-_map_radius, _map_radius))
	]

	for segment in wall_segments:
		var wall_body = PhysicsServer2D.body_create()
		_wall_bodies.append(wall_body)
		var segment_shape = PhysicsServer2D.segment_shape_create()

		PhysicsServer2D.body_set_space(wall_body, _physics_space)
		PhysicsServer2D.body_add_shape(wall_body, segment_shape)
		PhysicsServer2D.shape_set_data(segment_shape, segment)
		PhysicsServer2D.body_set_mode(wall_body, PhysicsServer2D.BodyMode.BODY_MODE_STATIC)
		PhysicsServer2D.body_set_collision_layer(wall_body, 1)
		PhysicsServer2D.body_set_collision_mask(wall_body, 1)

		PhysicsServer2D.body_set_state(wall_body, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D())

func get_wall_shape(body: RID) -> Rect2:
	var shape = PhysicsServer2D.body_get_shape(body, 0)
	return PhysicsServer2D.shape_get_data(shape)

func get_transform(body: RID) -> Transform2D:
	var transform = PhysicsServer2D.body_get_state(body, PhysicsServer2D.BodyState.BODY_STATE_TRANSFORM)
	return transform

func new_game():
	_actions_taken = 0
	var max_p = _map_radius - _hero._radius - _wall_thickness
	var p_hero = Vector2.ZERO
	var p_target = Vector2.ZERO

	while p_hero.distance_to(p_target) < max_p / 2.0:
		var r1 = randf_range(-max_p , max_p)
		var r2 = randf_range(-max_p , max_p)
		p_hero = Vector2(r1, r2)

		var r3 = randf_range(-max_p , max_p)
		var r4 = randf_range(-max_p , max_p)
		p_target = Vector2(r3, r4)

	_hero.set_transform(p_hero, randf_range(-PI, PI))
	_target.set_transform(p_target, 0)
	_initial_hero_position = _hero._position
	_prev_action = [0.0, 0.0]
	_prev_observation = _get_hero_observation()

func is_game_complete() -> bool:
	return _hero._position.distance_to(_target._position) < _hero._radius + _target._radius

func apply_action(action_vector: Array[float], callback):
	var motion_vector = Vector2(action_vector[0], action_vector[1]) * _hero._radius
	var hero_transform: Transform2D = get_transform(_hero._physics_body)
	var space_state = PhysicsServer2D.space_get_direct_state(_physics_space)

	var origin_of_hero = hero_transform.origin

	var motion_query = PhysicsShapeQueryParameters2D.new()
	motion_query.collide_with_areas = false
	motion_query.collide_with_bodies = true
	motion_query.margin = _wall_thickness
	motion_query.motion = motion_vector
	motion_query.shape_rid = _hero._physics_shape
	motion_query.transform = hero_transform
	motion_query.collision_mask = _hero_layer

	var result = space_state.cast_motion(motion_query)
	var motion_magnitude = result[0]

	_prev_action = action_vector
	_prev_observation = _get_hero_observation()

	_actions_taken += 1

	_hero.set_transform(_hero._position + motion_vector * motion_magnitude, motion_vector.angle())

	if callback:
		callback.call(self)

func get_game_state() -> Array[float]:
	var current = _get_hero_observation()
	var state = current + _prev_observation + _prev_action
	return state

func _get_hero_observation() -> Array[float]:
	var state: Array[float] = [
		(_hero._rotation / PI) - 1.0
	]
	var angles = _hero.get_vision_angles()
	for a in angles:
		var obs = _get_hero_target_observation(a, _hero.max_vision_distance)
		state.append(obs)

	return state

func _get_hero_target_observation(angle: float, max_distance: float) -> float:
	var space_state = PhysicsServer2D.space_get_direct_state(_physics_space)
	var hero_transform: Transform2D = get_transform(_hero._physics_body)
	var origin_of_hero = hero_transform.origin

	# Define the motion query
	var motion_query = PhysicsShapeQueryParameters2D.new()
	motion_query.collide_with_areas = false
	motion_query.collide_with_bodies = true
	motion_query.margin = _wall_thickness
	motion_query.motion = Vector2.from_angle(angle) * max_distance
	motion_query.shape_rid = _hero._physics_shape
	motion_query.transform = hero_transform
	motion_query.collision_mask = _target_layer

	var result = space_state.cast_motion(motion_query)
	return result[0]

func get_score() -> float:
	if is_game_complete():
		return 1.0
	return -1.0

func rescore_history(history: Array[Replay]):
	return
	#if history.is_empty():
		#return
	#var final_reward = history[history.size() - 1].reward
	#var did_complete = history[history.size() - 1].done
#
	#var history_size: float = float(history.size())
	#var index: float = 0.0
	#for replay in history:
		#index += 1.0
		#var action_confidence = replay.action[1]
		#replay.reward = final_reward * (index / history_size) - history_size * 0.01
		#replay.reward *= action_confidence


func create_hindsight_replays(history: Array[Replay]) -> Array[Replay]:
	var hindsight_replays: Array[Replay] = []
	if history.size() < 2:
		return hindsight_replays

	var final_hero_position: Vector2 = _hero._position
	var initial_hero_state: Array[float] = history[0].state
	var initial_hero_position: Vector2 = _initial_hero_position
	var initial_hero_rotation = initial_hero_state[0] * 2 * PI

	_target._position = final_hero_position
	_hero.set_transform(initial_hero_position, initial_hero_rotation)

	if is_game_complete():
		return hindsight_replays

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

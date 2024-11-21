extends BaseSimulation

class_name FCGSimulation

var _hero: FCGHero = FCGHero.new()
var _target: FCGTarget = FCGTarget.new()

var _map_size: float = 500
var _map_radius: float:
	get:
		return _map_size/2

var _actions_taken = 0

var _prev_action: Array[float] = [0.0, 0.0]
var _prev_observation: Array[float] = []
var _initial_hero_position: Vector2

var _wall_thickness: float = 5

var _physics_space: RID
var _boundary_wall_bodies: Array[RID] = []
var _inner_wall_bodies: Array[RID] = []

var _hero_layer   = 0b0001
var _target_layer = 0b0010
var _wall_layer   = 0b0100

func _init():
	_setup_physics_server()

func cleanup_simulation():
	if _is_cleaned:
		return
	super.cleanup_simulation()
	_free_all_objects()

func _free_all_objects():
	PhysicsServer2D.free_rid(_hero._physics_shape)
	PhysicsServer2D.free_rid(_hero._physics_body)
	PhysicsServer2D.free_rid(_target._physics_shape)
	PhysicsServer2D.free_rid(_target._physics_body)
	for wall in _boundary_wall_bodies + _inner_wall_bodies:
		var shape_count = PhysicsServer2D.body_get_shape_count(wall)
		var range = range(shape_count)
		range.reverse()
		for index in range:
			var shape = PhysicsServer2D.body_get_shape(wall, index)
			PhysicsServer2D.free_rid(shape)
		PhysicsServer2D.free_rid(wall)
	PhysicsServer2D.free_rid(_physics_space)


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
		var wall_body = _add_wall(segment)
		_boundary_wall_bodies.append(wall_body)

func _add_wall(segment: Rect2) -> RID:
	var wall_body = PhysicsServer2D.body_create()
	var segment_shape = PhysicsServer2D.segment_shape_create()

	PhysicsServer2D.body_set_space(wall_body, _physics_space)
	PhysicsServer2D.body_add_shape(wall_body, segment_shape)
	PhysicsServer2D.shape_set_data(segment_shape, segment)
	PhysicsServer2D.body_set_mode(wall_body, PhysicsServer2D.BodyMode.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_collision_layer(wall_body, _wall_layer)
	PhysicsServer2D.body_set_collision_mask(wall_body, 0xFFFF)

	PhysicsServer2D.body_set_state(wall_body, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D())
	return wall_body

func get_wall_shape(body: RID) -> Rect2:
	var shape = PhysicsServer2D.body_get_shape(body, 0)
	return PhysicsServer2D.shape_get_data(shape)

func get_transform(body: RID) -> Transform2D:
	var transform = PhysicsServer2D.body_get_state(body, PhysicsServer2D.BodyState.BODY_STATE_TRANSFORM)
	return transform

func new_game(physics_update: Signal) -> bool:
	for body in _inner_wall_bodies:
		var shape_count = PhysicsServer2D.body_get_shape_count(body)
		for i in range(shape_count):
			var shape_rid = PhysicsServer2D.body_get_shape(body, i)
			PhysicsServer2D.free_rid(shape_rid)  # Free the shape RID

		# Free the body RID
		PhysicsServer2D.free_rid(body)

	_inner_wall_bodies = []

	_actions_taken = 0
	var max_p = _map_radius * 0.75
	var p_hero = Vector2.ZERO
	var p_target = Vector2.ZERO
	var wall_segment = Rect2(randf_range(-max_p , max_p), randf_range(-max_p , max_p), randf_range(-max_p , max_p), randf_range(-max_p , max_p))

	while wall_segment.position.distance_to(wall_segment.size) < max_p * 0.75:
		wall_segment = Rect2(randf_range(-max_p , max_p), randf_range(-max_p , max_p), randf_range(-max_p , max_p), randf_range(-max_p , max_p))

	var inner_wall = _add_wall(wall_segment)
	_inner_wall_bodies.append(inner_wall)

	var is_done = false
	while !is_done:
		await physics_update

		p_hero = Vector2.ZERO
		p_target = Vector2.ZERO
		while p_hero.distance_to(p_target) < _map_radius:
			p_hero = Vector2(randf_range(-max_p , max_p), randf_range(-max_p , max_p))
			p_target = Vector2(randf_range(-max_p , max_p), randf_range(-max_p , max_p))

		var t_hero = Transform2D(0, p_hero)
		var t_target = Transform2D(0, p_target)

		var temp_hero_body = PhysicsServer2D.body_create()
		var temp_hero_shape = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(temp_hero_shape, _hero._radius)
		PhysicsServer2D.body_add_shape(temp_hero_body, temp_hero_shape)
		PhysicsServer2D.body_set_state(temp_hero_body, PhysicsServer2D.BODY_STATE_TRANSFORM, t_hero)
		PhysicsServer2D.body_set_space(temp_hero_body, _physics_space)
		PhysicsServer2D.body_set_collision_layer(temp_hero_body, _hero_layer)

		var temp_target_body = PhysicsServer2D.body_create()
		var temp_target_shape = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(temp_target_shape, _target._radius)
		PhysicsServer2D.body_add_shape(temp_target_body, temp_target_shape)
		PhysicsServer2D.body_set_state(temp_target_body, PhysicsServer2D.BODY_STATE_TRANSFORM, t_target)
		PhysicsServer2D.body_set_space(temp_target_body, _physics_space)
		PhysicsServer2D.body_set_collision_layer(temp_target_body, _target_layer)

		var direct_state = PhysicsServer2D.space_get_direct_state(_physics_space)
		var query = PhysicsShapeQueryParameters2D.new()
		query.margin = _hero._radius * 2
		query.shape_rid = temp_hero_shape
		query.transform = t_hero
		query.collision_mask = _wall_layer | _target_layer
		var result = direct_state.collide_shape(query, 1)

		query.shape_rid = temp_target_shape
		query.transform = t_target
		query.collision_mask = _wall_layer
		result += direct_state.collide_shape(query, 1)

		PhysicsServer2D.free_rid(temp_hero_shape)
		PhysicsServer2D.free_rid(temp_hero_body)
		PhysicsServer2D.free_rid(temp_target_shape)
		PhysicsServer2D.free_rid(temp_target_body)

		if result.is_empty():
			break

	_hero.set_transform(p_hero, randf_range(-PI, PI))
	_target.set_transform(p_target, 0)

	_initial_hero_position = p_hero
	_prev_action = [0.0, 0.0]
	_prev_observation = _get_hero_observation()

	return true

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
	motion_query.collision_mask = _wall_layer

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
	if _prev_observation.size() != current.size():
		_prev_observation = current
	var state = current + _prev_observation + _prev_action
	return state

func _get_hero_observation() -> Array[float]:
	var state: Array[float] = [
		(_hero._rotation / PI) - 1.0
	]
	var angles = _hero.get_vision_angles()
	var angle_to_wall_distance = {}
	for a in angles:
		var obs = _get_hero_layer_observation(a, _hero.max_vision_distance, _wall_layer)
		state.append(obs)
		angle_to_wall_distance[a] = obs
	for a in angles:
		var obs = _get_hero_layer_observation(a, _hero.max_vision_distance, _target_layer)
		if obs > angle_to_wall_distance[a]:
			obs = 1
		state.append(obs)

	return state

func _get_hero_layer_observation(angle: float, max_distance: float, layer: int) -> float:
	var space_state = PhysicsServer2D.space_get_direct_state(_physics_space)
	var hero_transform: Transform2D = get_transform(_hero._physics_body)
	var origin_of_hero = hero_transform.origin

	# Define the motion query
	var motion_query = PhysicsShapeQueryParameters2D.new()
	motion_query.collide_with_areas = false
	motion_query.collide_with_bodies = true
	motion_query.margin = 0
	motion_query.motion = Vector2.from_angle(angle) * max_distance
	motion_query.shape_rid = _hero._physics_shape
	motion_query.transform = hero_transform
	motion_query.collision_mask = layer

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


func create_hindsight_replays(history: Array[Replay], physics_update_signal = null) -> Array[Replay]:
	var hindsight_replays: Array[Replay] = []
	if history.size() < 2:
		return hindsight_replays

	await physics_update_signal

	var final_hero_position: Vector2 = _hero._position
	var initial_hero_state: Array[float] = history[0].state
	var initial_hero_position: Vector2 = _initial_hero_position
	var initial_hero_rotation = (initial_hero_state[0] + 1) * PI

	_target.set_transform(final_hero_position, 0)
	_hero.set_transform(initial_hero_position, initial_hero_rotation)
	await physics_update_signal

	if is_game_complete():
		return hindsight_replays

	for replay in history:
		var state = get_game_state()
		var action = replay.action
		apply_action(action, null)
		await physics_update_signal
		await physics_update_signal

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

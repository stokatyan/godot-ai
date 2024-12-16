extends BaseSimulation

class_name BRSimulation

var agent_names: Array[String] = ["001"]

var _agents: Array[BRAgent] = [BRAgent.new(), BRAgent.new()]
var _agent_teams: Array[int] = [1, 2]

var _map_size: float = 500
var _map_radius: float:
	get:
		return _map_size/2

var _agents_to_prev_actions = {}
var _action_history_size = 10

var _agents_to_prev_observations= {}
var _observation_history_size = 10

var _wall_thickness: float = 5

var _physics_space: RID
var _boundary_wall_bodies: Array[RID] = []
var _inner_wall_bodies: Array[RID] = []

var _team1_layer   = 0b0001
var _team2_layer = 0b0010
var _wall_layer   = 0b0100

func _init():
	_setup_physics_server()
	_reset_prev_actions()
	_reset_prev_observations()

func _setup_physics_server():
	_physics_space = PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(_physics_space, true)

	PhysicsServer2D.body_set_space(_agents[0]._physics_body, _physics_space)
	PhysicsServer2D.body_set_collision_layer(_agents[0]._physics_body, _team1_layer)
	PhysicsServer2D.body_set_collision_mask(_agents[0]._physics_body, _team1_layer)

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

func _reset_prev_actions():
	for agent in _agents:
		var history: Array[float] = []

		for i in range(_action_history_size):
			history.append(0.0)
			history.append(0.0)

		_agents_to_prev_actions[agent] = history

func _reset_prev_observations():
	for agent_index in get_agents_count():
		var obs = _get_current_observation(agent_index)
		var prev_observations = []
		for i in range(_observation_history_size):
			prev_observations.append(obs)
		_agents_to_prev_observations[_agents[agent_index]] = prev_observations

func _get_current_observation(agent_index: int) -> Array[float]:
	var agent = _agents[agent_index]
	var state: Array[float] = [
		(agent._rotation / PI)
	]

	var angles = agent.get_vision_angles()
	var angle_to_wall_distance = {}
	var agent_team = _agent_teams[agent_index]

	var enemy_layer = _team1_layer | _team2_layer
	if agent_team == 1:
		enemy_layer = enemy_layer & ~_team1_layer
	if agent_team == 2:
		enemy_layer = enemy_layer & ~_team2_layer

	for a in angles: # Walls
		var obs = _get_agent_observation(agent, a, agent.max_vision_distance, _wall_layer)
		state.append(obs)
		angle_to_wall_distance[a] = obs
	for a in angles: # Enemies
		var obs = _get_agent_observation(agent, a, agent.max_vision_distance, enemy_layer)
		var t = agent._transform
		t.origin += Vector2.from_angle(a) * _agents[0]._radius
		var target_collision_points = _get_collision_points(agent._physics_shape, t, 0, enemy_layer)

		if !target_collision_points.is_empty():
			obs = 0.2 * agent._position.distance_to(target_collision_points[1]) / agent.max_vision_distance

		if obs > angle_to_wall_distance[a]:
			obs = 1
		state.append(obs)

	state.append(agent._position.x / _map_radius)
	state.append(agent._position.y / _map_radius)

	state += agent.get_stats()

	return state

func _get_agent_observation(agent: BRAgent, angle: float, max_distance: float, layer: int) -> float:
	var space_state = PhysicsServer2D.space_get_direct_state(_physics_space)
	var agent_transform: Transform2D = get_transform(agent._physics_body)

	# Define the motion query
	var motion_query = PhysicsShapeQueryParameters2D.new()
	motion_query.collide_with_areas = false
	motion_query.collide_with_bodies = true
	motion_query.margin = 0
	motion_query.motion = Vector2.from_angle(angle) * max_distance
	motion_query.shape_rid = agent._physics_shape
	motion_query.transform = agent_transform
	motion_query.collision_mask = layer

	var result = space_state.cast_motion(motion_query)
	return result[0]

func _get_collision_points(shape_rid: RID, transform: Transform2D, margin: float, collision_mask: int) -> Array[Vector2]:
	var direct_state = PhysicsServer2D.space_get_direct_state(_physics_space)
	var query = PhysicsShapeQueryParameters2D.new()
	query.margin = margin
	query.shape_rid = shape_rid
	query.transform = transform
	query.collision_mask = collision_mask
	var result = direct_state.collide_shape(query, 1)
	return result

func get_score(agent_index: int) -> float:
	var agent = _agents[agent_index]
	var team = _agent_teams[agent_index]
	var winning_team = _get_winning_team()
	if winning_team <= 0:
		if agent.is_dead:
			return -10
		return 0
	if winning_team == team:
		return 10
	else:
		return -100

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

func get_agent_names() -> Array[String]:
	return agent_names

func get_agents_count() -> int:
	return _agents.size()

func get_agent_name(agent_index: int) -> String:
	if agent_index == 0:
		return agent_names[0]
	return agent_names[1]

## New Game

func new_game(physics_update: Signal) -> bool:
	for body in _inner_wall_bodies:
		var shape_count = PhysicsServer2D.body_get_shape_count(body)
		for i in range(shape_count):
			var shape_rid = PhysicsServer2D.body_get_shape(body, i)
			PhysicsServer2D.free_rid(shape_rid)  # Free the shape RID

		# Free the body RID
		PhysicsServer2D.free_rid(body)

	var max_p = _map_radius * 0.75
	var p_hero = Vector2.ZERO

	var last_wall_was_vertical = false
	for i in range(0, randi_range(1, 4)):
		var p1 = Vector2(randf_range(-max_p, max_p), randf_range(-max_p, max_p))
		var p2 = Vector2()
		if !last_wall_was_vertical: # Random choice
			# Vertical line
			p2 = Vector2(p1.x + randf_range(-20, 20), randf_range(-max_p, max_p))
			last_wall_was_vertical = true
		else:
			# Horizontal line
			p2 = Vector2(randf_range(-max_p, max_p), p1.y + randf_range(-20, 20))
			last_wall_was_vertical = false

		if p1.distance_to(p2) < 20:
			continue

		var wall_segment = Rect2(p1.x, p1.y, p2.x, p2.y)

		var inner_wall = _add_wall(wall_segment)
		_inner_wall_bodies.append(inner_wall)

	var is_done = false
	while !is_done:
		await physics_update

		p_hero = Vector2(randf_range(-max_p , max_p), randf_range(-max_p , max_p))

		var t_hero = Transform2D(0, p_hero)
		var temp_hero_body = PhysicsServer2D.body_create()
		var temp_hero_shape = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(temp_hero_shape, _agents[0]._radius)
		PhysicsServer2D.body_add_shape(temp_hero_body, temp_hero_shape)
		PhysicsServer2D.body_set_state(temp_hero_body, PhysicsServer2D.BODY_STATE_TRANSFORM, t_hero)
		PhysicsServer2D.body_set_space(temp_hero_body, _physics_space)
		PhysicsServer2D.body_set_collision_layer(temp_hero_body, _team1_layer)

		var result: Array[Vector2] = _get_collision_points(temp_hero_shape, t_hero, _agents[0]._radius * 2, _wall_layer)

		if result.is_empty():
			is_done = true
			break

	_agents[0].set_transform(p_hero, randf_range(-PI, PI))

	_reset_prev_actions()
	_reset_prev_observations()

	return true

func cleanup_simulation():
	if _is_cleaned:
		return
	_free_all_objects()
	_is_cleaned = true

func _free_all_objects():
	PhysicsServer2D.free_rid(_agents[0]._physics_shape)
	PhysicsServer2D.free_rid(_agents[0]._physics_body)
	for wall in _boundary_wall_bodies + _inner_wall_bodies:
		var shape_count = PhysicsServer2D.body_get_shape_count(wall)
		var range_of_count = range(shape_count)
		range_of_count.reverse()
		for index in range_of_count:
			var shape = PhysicsServer2D.body_get_shape(wall, index)
			PhysicsServer2D.free_rid(shape)
		PhysicsServer2D.free_rid(wall)
	PhysicsServer2D.free_rid(_physics_space)

func is_game_complete(agent_index: int) -> bool:
	return _get_winning_team() > 0

func _get_winning_team() -> int:
	var teams_alive_map = {}
	for team in _agent_teams:
		teams_alive_map[team] = false

	for i in range(_agents.size()):
		var is_team_alive = teams_alive_map[_agent_teams[i]]
		teams_alive_map[_agent_teams[i]] = is_team_alive or _agents[i].is_dead

	var winning_team = -1
	var teams_alive = 0
	for team in teams_alive_map.keys():
		var val = teams_alive_map[team]
		if val:
			winning_team = team
			teams_alive += 1

	if teams_alive >= 2:
		return -1
	return winning_team


func apply_action(agent_index: int, action_vector: Array[float], callback):
	var agent = _agents[agent_index]
	if agent.is_dead:
		return
	var motion_vector = Vector2(action_vector[0], action_vector[1]) * agent._radius
	var rotation = action_vector[2] * PI

	var shoot_action: bool = action_vector[3] > 0.0
	var reload_action: bool = action_vector[4] > 0.0

	var transform: Transform2D = get_transform(agent._physics_body)
	var space_state = PhysicsServer2D.space_get_direct_state(_physics_space)

	var motion_query = PhysicsShapeQueryParameters2D.new()
	motion_query.collide_with_areas = false
	motion_query.collide_with_bodies = true
	motion_query.margin = _wall_thickness
	motion_query.motion = motion_vector
	motion_query.shape_rid = agent._physics_shape
	motion_query.transform = transform
	motion_query.collision_mask = _wall_layer

	var result = space_state.cast_motion(motion_query)
	var motion_magnitude = result[0]

	var prev_actions = _agents_to_prev_actions[agent]
	prev_actions += action_vector
	for action in range(0, 5):
		prev_actions.pop_front()

	_agents_to_prev_actions[agent] = prev_actions

	var prev_observations = _agents_to_prev_observations[agent]
	prev_observations.append(_get_current_observation(agent_index))
	prev_observations.pop_front()
	_agents_to_prev_observations[agent] = prev_observations

	agent.step_did_elapse()

	if shoot_action:
		agent.shoot()
	if reload_action:
		agent.reload()
	agent.set_transform(agent._position + motion_vector * motion_magnitude, rotation)

	if callback:
		callback.call(self)

func get_state(agent_index: int) -> Array[float]:
	var current = _get_current_observation(agent_index)
	var agent = _agents[agent_index]
	var prev_observations = _agents_to_prev_observations[agent]
	if prev_observations.size() != _observation_history_size:
		_reset_prev_observations()

	prev_observations = _agents_to_prev_observations[agent]
	var flattened_prev_observatations: Array[float] = []
	for obs in prev_observations:
		flattened_prev_observatations += obs
	var prev_actions: Array[float] = _agents_to_prev_actions[agent]

	var state = current + flattened_prev_observatations + prev_actions
	return state

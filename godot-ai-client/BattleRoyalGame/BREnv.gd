extends AIBaseEnvironment

var _sims_to_display: Array[BRSimulation] = []
var _example_sim: BRSimulation = BRSimulation.new()
var _display_offsets: Array[Vector2] = [Vector2(-600, 0), Vector2(0, 0), Vector2(600, 0)]

@export var epoch_label: Label
@export var state_label: Label

func _draw():
	if _sims_to_display.is_empty():
		return
	for index in range(0, get_number_of_simulations_to_display()):
		var sim = _sims_to_display[index]
		_draw_simulation(sim, _display_offsets[index], index)

func _input(event):
	var keyboard_event = event as InputEventKey

	if keyboard_event and keyboard_event.is_pressed():
		_handle_user_input(keyboard_event.keycode)

func _handle_user_input(_key: Key):
	var apply_move = false
	var move_vector: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		apply_move = true
		move_vector += Vector2.UP
	if Input.is_key_pressed(KEY_A):
		apply_move = true
		move_vector += Vector2.LEFT
	if Input.is_key_pressed(KEY_S):
		apply_move = true
		move_vector += Vector2.DOWN
	if Input.is_key_pressed(KEY_D):
		apply_move = true
		move_vector += Vector2.RIGHT

	var rotation = move_vector.angle()
	var agent_index = 0
	var shoot = -1.0
	if Input.is_key_pressed(KEY_SHIFT):
		rotation = move_vector.angle()
		move_vector = Vector2.ZERO

		if Input.is_key_pressed(KEY_SPACE):
			shoot = 1.0
			apply_move = true

	if apply_move and !_ai_runner._initial_simulations.is_empty():
		var action: Array[float] = [move_vector.x, move_vector.y, rotation/PI]

		action.append(shoot)
		action.append(0.0)

		_ai_runner._initial_simulations[0].apply_action(agent_index, action, null)
		await get_tree().physics_frame
		await get_tree().physics_frame
		queue_redraw()

func display_simulation(s: BaseSimulation):
	await get_tree().physics_frame
	await get_tree().physics_frame

	_sims_to_display.append(s)
	while _sims_to_display.size() > get_number_of_simulations_to_display():
		_sims_to_display.pop_front()

	queue_redraw()

func new_simulation() -> BaseSimulation:
	return BRSimulation.new() as BRSimulation

func get_simulation_count() -> int:
	return 20

func get_steps_in_round() -> int:
	return 105

func get_state_dim(_agent_name: String) -> int:
	return _example_sim.get_state(0).size() # Only 1 type of agent

func get_action_dim(_agent_name: String) -> int:
	return 5

func get_batch_size(_agent_name: String) -> int:
	return 500

func get_num_actor_layers(_agent_name: String) -> int:
	return 6

func get_num_critic_layers(_agent_name: String) -> int:
	return 8

func get_hidden_size(_agent_name: String) -> int:
	return 200

func get_train_steps(_agent_name: String) -> int:
	return 100

func _draw_simulation(s: BRSimulation, offset: Vector2, sim_index: int):
	if s._is_cleaned:
		return

	var colors = [Color.SEA_GREEN, Color.DODGER_BLUE]
	for agent_index in range(0, s.get_agents_count()):
		# Vision
		var agent = s._agents[agent_index]
		var vision_angles = agent.get_vision_angles()
		var game_state = s.get_state(agent_index)
		if sim_index == 0:
			for i in range(vision_angles.size()):
				var a = vision_angles[i]
				var wall_depth = game_state[i + 1] # first item is rotation
				var target_depth = game_state[i + 1 + vision_angles.size()] # first item is rotation
				target_depth = min(wall_depth, target_depth)
				var direction = Vector2.from_angle(a)
				draw_line(
					agent._position + direction * agent._radius + offset,
					agent._position + direction * wall_depth * agent.max_vision_distance + direction * agent._radius + offset,
					Color.DARK_GRAY,
					3.5,
					true
				)
				draw_line(
					agent._position + direction * agent._radius + offset,
					agent._position + direction * target_depth * agent.max_vision_distance + direction * agent._radius + offset,
					Color.STEEL_BLUE,
					0.75,
					true
				)

		var color = colors[s._agent_teams[agent_index] - 1]
		# Agent
		draw_circle(
			agent._position + offset,
			agent._radius,
			colors[agent_index]
		)
		draw_circle(
			agent._position + offset,
			agent._radius,
			colors[agent_index],
			false,
			2.0,
			true
		)


		# Orientation
		draw_line(
			agent._position + offset,
			agent._position + Vector2.from_angle(agent._rotation) * agent._radius + offset,
			Color.WHITE_SMOKE,
			3,
			true
		)

		# Bullet
		draw_line(
			Vector2(agent.last_shot_line.x, agent.last_shot_line.y) + offset,
			Vector2(agent.last_shot_line.z, agent.last_shot_line.w) + offset,
			Color.RED,
			1.0 * (agent._fire_delay_remaining/agent._fire_delay_per_shot),
			true
		)

		# Health
		var half_width = agent._radius * 0.9
		var stat_root = Vector2(agent._position.x - half_width, agent._position.y)
		stat_root += offset
		stat_root.y += 10
		draw_line(
			stat_root,
			stat_root + Vector2(2 * half_width, 0),
			Color.BLACK,
			3,
			true
		)
		draw_line(
			stat_root,
			stat_root + Vector2(agent._health * 2 * half_width, 0),
			Color.INDIAN_RED,
			2,
			true
		)

		stat_root.y += 5
		var ammo_percent = agent._current_ammo / agent._ammo_per_reload
		if agent._current_ammo == 0:
			ammo_percent = 1.0 - agent._reload_delay_remaining/agent._reload_time
		# Ammo
		draw_line(
			stat_root,
			stat_root + Vector2(2 * half_width, 0),
			Color.BLACK,
			3,
			true
		)
		draw_line(
			stat_root,
			stat_root + Vector2(ammo_percent * 2 * half_width, 0),
			Color.GRAY,
			2,
			true
		)

	# Walls
	for body in s._boundary_wall_bodies + s._inner_wall_bodies:
		var shape_rect = s.get_wall_shape(body)
		var p0 = shape_rect.position + offset
		var p1 = shape_rect.size + offset
		draw_line(p0, p1, Color.BLACK, s._wall_thickness, true)

func update_status(epoch: int, message: String):
	epoch_label.text = str(epoch)
	state_label.text = message

func get_agent_names() -> Array[String]:
	return _example_sim.get_agent_names()

func get_number_of_simulations_to_display() -> int:
	return min(_display_offsets.size(), get_simulation_count())

func get_is_deterministic_map(epoch: int) -> Dictionary:
	var agent_names = _example_sim.get_agent_names()
	var discrete_map = {}
	discrete_map[agent_names[0]] = false

	return discrete_map

func get_replay_capacity(agent_name: String) -> int:
	return 1_000_000

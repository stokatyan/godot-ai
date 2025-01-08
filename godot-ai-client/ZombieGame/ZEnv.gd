extends AIBaseEnvironment

var _sims_to_display: Array[ZSimulation] = []
var _example_sim: ZSimulation = ZSimulation.new()
var _display_offsets: Array[Vector2] = [Vector2(-600, 0), Vector2(0, 0), Vector2(600, 0)]

@export var epoch_label: Label
@export var state_label: Label

var _is_soldier_deterministic = false
var _is_zombie_deterministic = false

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
		if keyboard_event.keycode == KEY_7:
			_is_soldier_deterministic = false
			print("_is_soldier_deterministic: " + str(_is_soldier_deterministic))
		if keyboard_event.keycode == KEY_8:
			_is_soldier_deterministic = true
			print("_is_soldier_deterministic: " + str(_is_soldier_deterministic))
		if keyboard_event.keycode == KEY_9:
			_is_zombie_deterministic = false
			print("_is_zombie_deterministic: " + str(_is_zombie_deterministic))
		if keyboard_event.keycode == KEY_0:
			_is_zombie_deterministic = true
			print("_is_zombie_deterministic: " + str(_is_zombie_deterministic))

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
	if Input.is_key_pressed(KEY_CTRL):
		agent_index = 1

	if apply_move and !_ai_runner._initial_simulations.is_empty():
		var action: Array[float] = [move_vector.x, move_vector.y, rotation/PI]

		action.append(shoot)
		action.append(0.0)

		_ai_runner._initial_simulations[0].apply_action(agent_index, action, null)
		await get_tree().physics_frame
		await get_tree().physics_frame
		queue_redraw()
		print("-- scores --")
		print("agent 0 score: " + str(_ai_runner._initial_simulations[0].get_score(0)))
		print("agent 1 score: " + str(_ai_runner._initial_simulations[0].get_score(1)))
		print("agent 2 score: " + str(_ai_runner._initial_simulations[0].get_score(2)))
		print()

func display_simulation(s: BaseSimulation):
	await get_tree().physics_frame
	await get_tree().physics_frame

	_sims_to_display.append(s)
	while _sims_to_display.size() > get_number_of_simulations_to_display():
		_sims_to_display.pop_front()

	queue_redraw()

func new_simulation() -> BaseSimulation:
	return ZSimulation.new() as ZSimulation

func get_simulation_count() -> int:
	return 25

func get_steps_in_round() -> int:
	return 90

func get_state_dim(_agent_name: String) -> int:
	if _agent_name == _example_sim.agent_names[0]:
		return _example_sim.get_state(0).size()
	else:
		return _example_sim.get_state(1).size()

func get_action_dim(_agent_name: String) -> int:
	if _agent_name == _example_sim.agent_names[0]:
		return 5
	else:
		return 3

func get_batch_size(_agent_name: String) -> int:
	return 500

func get_num_actor_layers(_agent_name: String) -> int:
	return 6

func get_num_critic_layers(_agent_name: String) -> int:
	return 8

func get_hidden_size(_agent_name: String) -> int:
	return 200

func get_train_steps(_agent_name: String) -> int:
	return 90

func _draw_simulation(s: ZSimulation, offset: Vector2, sim_index: int):
	if s._is_cleaned:
		return

	var colors = [Color.SEA_GREEN, Color.MEDIUM_PURPLE]
	for agent_index in range(0, s.get_agents_count()):
		var agent = s._agents[agent_index]

		# Vision
		var vision_angles = agent.get_vision_angles()
		var game_state = s.get_state(agent_index)
		if sim_index == 0:
			for i in range(vision_angles.size()):
				var a = vision_angles[i]
				var wall_depth = game_state[i + 1] # first item is rotation
				var target_depth = game_state[i + 1 + vision_angles.size()] # first item is rotation
				var friend_depth = game_state[i + 1 + vision_angles.size()*2]
				target_depth = min(wall_depth, target_depth)
				friend_depth = min(wall_depth, friend_depth)
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
					1.75,
					true
				)
				draw_line(
					agent._position + direction * agent._radius + offset,
					agent._position + direction * friend_depth * agent.max_vision_distance + direction * agent._radius + offset,
					Color.BURLYWOOD,
					0.5,
					true
				)

		var color = colors[min(s._agent_teams[agent_index] - 1, 1)]
		# Agent
		if !agent.is_dead:
			draw_circle(
				agent._position + offset,
				agent._radius,
				color
			)
		draw_circle(
			agent._position + offset,
			agent._radius,
			color,
			false,
			2.0,
			true
		)

		# Orientation
		draw_line(
			agent._position + offset,
			agent._position + Vector2.from_angle(agent._rotation) * agent._radius * 1.1 + offset,
			Color.WHITE_SMOKE,
			3,
			true
		)

		# Bullet
		var soldier = agent as ZSoldier
		var zombie = agent as ZZombie
		if soldier:
			var bullet_color = Color.RED
			bullet_color.a = (agent._fire_delay_remaining/agent._fire_delay_per_shot)
			draw_line(
				Vector2(agent.last_shot_line.x, agent.last_shot_line.y) + offset,
				Vector2(agent.last_shot_line.z, agent.last_shot_line.w) + offset,
				bullet_color,
				5.0 * agent._attack_damage,
				true
			)
		if zombie:
			draw_arc(
				zombie._position + offset,
				zombie._attack_range,
				zombie._rotation - PI/8.0,
				zombie._rotation + PI/8.0, 10,
				Color.INDIAN_RED,
				1,
				true
			)

		# Health
		var half_width = agent._radius * 0.8
		var stat_root = Vector2(agent._position.x - half_width, agent._position.y)
		stat_root += offset
		stat_root.y += 5
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
		if soldier:
			var ammo_percent = agent._current_ammo / agent._ammo_per_reload
			var ammo_color = Color.GRAY
			if agent._current_ammo == 0:
				ammo_percent = 1.0 - agent._reload_delay_remaining/agent._reload_time
				ammo_color = Color.DIM_GRAY
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
				ammo_color,
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

	discrete_map[agent_names[0]] = _is_soldier_deterministic
	discrete_map[agent_names[1]] = _is_zombie_deterministic

	return discrete_map

func get_replay_capacity(agent_name: String) -> int:
	return 300_000

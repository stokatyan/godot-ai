extends AIBaseEnvironment

var _sims_to_display: Array[FCGSimulation] = []
var _example_sim: FCGSimulation = FCGSimulation.new()
var _display_offsets: Array[Vector2] = [Vector2(-600, 0), Vector2(0, 0), Vector2(600, 0)]

@export var epoch_label: Label
@export var state_label: Label

var _is_training_hero = true
var _is_training_target = false

func _draw():
	if _sims_to_display.is_empty():
		return
	for index in range(0, get_number_of_simulations_to_display()):
		var sim = _sims_to_display[index]
		_draw_simulation(sim, _display_offsets[index])

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
	if Input.is_key_pressed(KEY_7):
		_is_training_hero = true
		_is_training_target = false
		print("_is_training_hero: " + str(_is_training_hero) + ", _is_training_target: " + str(_is_training_target))
	if Input.is_key_pressed(KEY_8):
		_is_training_hero = false
		_is_training_target = true
		print("_is_training_hero: " + str(_is_training_hero) + ", _is_training_target: " + str(_is_training_target))
	if Input.is_key_pressed(KEY_9):
		_is_training_hero = true
		_is_training_target = true
		print("_is_training_hero: " + str(_is_training_hero) + ", _is_training_target: " + str(_is_training_target))
	if Input.is_key_pressed(KEY_0):
		_is_training_hero = false
		_is_training_target = false
		print("_is_training_hero: " + str(_is_training_hero) + ", _is_training_target: " + str(_is_training_target))

	var agent_index = 0
	if Input.is_key_pressed(KEY_SHIFT):
		agent_index = 1

	if apply_move and !_ai_runner._initial_simulations.is_empty():
		var action: Array[float] = [move_vector.x, move_vector.y]

		_ai_runner._initial_simulations[0].apply_action(agent_index, action, null)
		await get_tree().physics_frame
		await get_tree().physics_frame
		queue_redraw()
		if _ai_runner._initial_simulations[0].is_game_complete(0):
			await get_tree().create_timer(0.5).timeout
			await _ai_runner._initial_simulations[0].new_game(get_tree().physics_frame)
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
	return FCGSimulation.new() as FCGSimulation

func get_simulation_count() -> int:
	return 50

func get_steps_in_round() -> int:
	return 55

func get_state_dim(_agent_name: String) -> int:
	if _agent_name == _example_sim.get_agent_names()[0]:
		return _example_sim.get_state(0).size()
	return _example_sim.get_state(1).size()

func get_action_dim(_agent_name: String) -> int:
	return 2

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

func _draw_simulation(s: FCGSimulation, offset: Vector2):
	if s._is_cleaned:
		return

	var colors = [Color.INDIAN_RED, Color.SEA_GREEN]
	for agent_index in range(0, s.get_agents_count()):
		# Vision
		var agent = s._agents[agent_index]
		var vision_angles = agent.get_vision_angles()
		var game_state = s.get_state(agent_index)
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
		# Agent
		draw_circle(
			agent._position + offset,
			agent._radius,
			colors[agent_index],
			false,
			2.0,
			true
		)
		# Filled circle
		draw_circle(
			agent._position + offset,
			agent._radius,
			colors[agent_index],
		)

		# Orientation
		draw_line(
			agent._position + offset,
			agent._position + Vector2.from_angle(agent._rotation) * agent._radius + offset,
			Color.WHITE_SMOKE,
			3,
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
	#var max_val = 500
	#var count = epoch % (max_val + 1)
	#if count == max_val:
		#_is_training_hero = !_is_training_hero
		#_is_training_target = !_is_training_target
	discrete_map[agent_names[0]] = !_is_training_hero
	discrete_map[agent_names[1]] = !_is_training_target

	return discrete_map

func get_replay_capacity(agent_name: String) -> int:
	if agent_name == get_agent_names()[0]:
		return 5_000_000
	return 100

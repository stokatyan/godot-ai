extends AIBaseEnvironment

var sim_to_display: FCGSimulation
var _example_sim: FCGSimulation = FCGSimulation.new()

@export var epoch_label: Label
@export var state_label: Label

func _draw():
	if !sim_to_display:
		return
	_draw_simulation(sim_to_display)

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

	if apply_move and !_ai_runner._initial_simulations.is_empty():
		var action: Array[float] = [move_vector.x, move_vector.y]
		_ai_runner._initial_simulations[0].apply_action(action, display_simulation)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if _ai_runner._initial_simulations[0].is_game_complete():
			await get_tree().create_timer(1).timeout
			await _ai_runner._initial_simulations[0].new_game(get_tree().physics_frame)
			display_simulation(_ai_runner._initial_simulations[0])

func display_simulation(s: BaseSimulation):
	await get_tree().physics_frame
	await get_tree().physics_frame

	sim_to_display = s
	queue_redraw()

func new_simulation() -> BaseSimulation:
	return FCGSimulation.new() as FCGSimulation

func get_simulation_count() -> int:
	return 60

func get_steps_in_round() -> int:
	return 100

func get_state_dim(agent_name: String) -> int:
	var example = _example_sim.get_game_state()
	return example.size()

func get_action_dim(agent_name: String) -> int:
	return 2

func get_batch_size(agent_name: String) -> int:
	return 500

func get_num_actor_layers(agent_name: String) -> int:
	return 3

func get_num_critic_layers(agent_name: String) -> int:
	return 4

func get_hidden_size(agent_name: String) -> int:
	return 200

func get_train_steps(agent_name: String) -> int:
	return 100

func _draw_simulation(s: FCGSimulation):
	if s._is_cleaned:
		return

	var colors = [Color.RED, Color.YELLOW]
	for agent_index in range(0, s.get_agents_count()):
		# Vision
		var agent = s._agents[agent_index]
		var vision_angles = agent.get_vision_angles()
		var game_state = s.get_state(agent_index)
		for i in range(vision_angles.size()):
			var a = vision_angles[i]
			var wall_depth = game_state[i + 1] # first item is rotation
			var target_depth = game_state[i + 1 + vision_angles.size()] # first item is rotation
			var direction = Vector2.from_angle(a)
			draw_line(
				agent._position + direction * agent._radius,
				agent._position + direction * wall_depth * agent.max_vision_distance + direction * agent._radius,
				Color.BURLYWOOD,
				4,
				true
			)
			draw_line(
				agent._position + direction * agent._radius,
				agent._position + direction * target_depth * agent.max_vision_distance + direction * agent._radius,
				Color.CADET_BLUE,
				1,
				true
			)
		# Agent
		draw_circle(
			agent._position,
			agent._radius,
			colors[agent_index],
			false,
			2.0,
			true
		)

		# Orientation
		draw_line(
			agent._position,
			agent._position + Vector2.from_angle(agent._rotation) * agent._radius,
			Color.WHITE_SMOKE,
			3,
			true
		)

	# Walls
	for body in s._boundary_wall_bodies + s._inner_wall_bodies:
		var shape_rect = s.get_wall_shape(body)
		var p0 = shape_rect.position
		var p1 = shape_rect.size
		draw_line(p0, p1, Color.BLACK, s._wall_thickness, true)

func update_status(epoch: int, message: String):
	epoch_label.text = str(epoch)
	state_label.text = message

func get_agent_names() -> Array[String]:
	return _example_sim.get_agent_names()

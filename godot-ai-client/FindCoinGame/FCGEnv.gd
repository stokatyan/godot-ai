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
	return 50

func get_steps_in_round() -> int:
	return 36

func get_state_dim() -> int:
	var example = _example_sim.get_game_state()
	return example.size()

func get_action_dim() -> int:
	return 2

func get_batch_size() -> int:
	return 256

func get_num_actor_layers() -> int:
	return 6

func get_num_critic_layers() -> int:
	return 8

func get_hidden_size() -> int:
	return 200

func get_train_steps() -> int:
	return 100

func _draw_simulation(s: FCGSimulation):
	if s._is_cleaned:
		return
	# Hero Vision
	var vision_angles = s._hero.get_vision_angles()
	var game_state = s.get_game_state()
	var h = s._hero
	for i in range(vision_angles.size()):
		var a = vision_angles[i]
		var wall_depth = game_state[i + 1] # first item is rotation
		var target_depth = game_state[i + 1 + vision_angles.size()] # first item is rotation
		var direction = Vector2.from_angle(a)
		draw_line(
			h._position + direction * h._radius,
			h._position + direction * wall_depth * h.max_vision_distance + direction * h._radius,
			Color.BURLYWOOD,
			4,
			true
		)
		draw_line(
			h._position + direction * h._radius,
			h._position + direction * target_depth * h.max_vision_distance + direction * h._radius,
			Color.CADET_BLUE,
			1,
			true
		)

	# Target
	draw_circle(
		s._target._position,
		s._target._radius,
		Color.YELLOW,
		false,
		2.0,
		true
	)

	# Hero
	draw_circle(
		s._hero._position,
		s._hero._radius,
		Color.RED,
		false,
		2.0,
		true
	)

	# Hero Orientation
	draw_line(
		h._position,
		h._position + Vector2.from_angle(h._rotation) * h._radius,
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

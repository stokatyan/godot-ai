extends AIBaseEnvironment

var sim_to_display: FCGSimulation

func _draw():
	if !sim_to_display:
		return
	_draw_simulation(sim_to_display)

func _physics_process(_delta):
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

	if apply_move and !_ai_runner._simulations.is_empty():
		var action: Array[float] = [move_vector.angle(), 1.0]
		_ai_runner._simulations[0].apply_action(action, display_simulation)
		if _ai_runner._simulations[0].is_game_complete():
			_ai_runner._simulations[0].new_game()
			display_simulation(_ai_runner._simulations[0])

func display_simulation(s: BaseSimulation):
	sim_to_display = s
	queue_redraw()

func new_simulation() -> BaseSimulation:
	return FCGSimulation.new() as FCGSimulation

func get_simulation_count() -> int:
	return 100

func get_state_dim() -> int:
	return 4

func get_action_dim() -> int:
	return 2

func get_batch_size() -> int:
	return 256

func get_num_actor_layers() -> int:
	return 2

func get_num_critic_layers() -> int:
	return 3

func get_hidden_size() -> int:
	return 40

func get_train_steps() -> int:
	return 10

func _draw_simulation(s: FCGSimulation):
	## Target
	draw_circle(
		s._target._position,
		s._target._radius,
		Color.YELLOW,
		true,
		1,
		true
	)

	## Hero
	draw_circle(
		s._hero._position,
		s._hero._radius,
		Color.RED,
		true,
		1,
		true
	)

	## Hero Vision
	var vision_angles = s._hero.get_vision_angles()
	var game_state = s.get_game_state()
	var h = s._hero
	for i in range(vision_angles.size()):
		var a = vision_angles[i]
		var d = game_state[i + 3] # first 3 items are x, y, rotation
		draw_line(
			h._position,
			h._position + Vector2.from_angle(a) * d,
			Color.CADET_BLUE,
			1,
			true
		)

	## Hero Orientation
	draw_line(
		h._position,
		h._position + Vector2.from_angle(h._rotation) * h._radius,
		Color.WHITE_SMOKE,
		3,
		true
	)

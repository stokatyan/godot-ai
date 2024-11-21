extends AIBaseEnvironment

@export var hero: Node2D
@export var coin: Node2D

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
		var action: Array[float] = [1.0, move_vector.angle()]
		_ai_runner._simulations[0].apply_action(action, display_simulation)
		if _ai_runner._simulations[0].is_game_complete():
			await _ai_runner._simulations[0].new_game(get_tree().process_frame)
			display_simulation(_ai_runner._simulations[0])
			return

func display_simulation(s: BaseSimulation):
	var simulation: PCGSimulation = s
	hero.position = simulation.hero_position
	coin.position = simulation.coin_position

func new_simulation() -> BaseSimulation:
	return PCGSimulation.new() as BaseSimulation

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

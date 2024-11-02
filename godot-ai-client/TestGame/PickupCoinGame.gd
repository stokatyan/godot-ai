extends Node2D

@export var hero: Node2D
@export var coin: Node2D
@export var _ai_tcp: AIServerTCP

var move_speed = 500

var _loop_train_count = 0
var _is_loop_training = false
var _is_testing = false

var _simulation_count = 100
var _simulations: Array[PCGSimulation] = []

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(_simulation_count):
		_simulations.append(PCGSimulation.new())

	_new_simulations()

func _input(event):
	var key_input = event as InputEventKey
	if !key_input:
		return

	if key_input.echo or key_input.is_released():
		return
	match key_input.keycode:
		KEY_ENTER:
			if _is_loop_training or _is_testing:
				return
			_is_testing = true
			var _result = await _get_batch_from_playing_round([_simulations[0]], true)
			_is_testing = false

		KEY_N:
			_new_simulations()
		KEY_UP:
			_setup_ai()
		KEY_1: # Get and Apply action
			var current_state = _simulations[0].get_game_state()
			var start_time = Time.get_ticks_msec()
			var action = await _ai_tcp.get_action(current_state)
			var _time_elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
			_simulations[0].move_hero(action[1], action[0], _display_simulation)
		KEY_2: # Get and Submit batch
			var replays = await _get_batch_from_playing_round(_simulations, false)
			var _response = await _ai_tcp.submit_batch_replay(replays)
		KEY_3: # Start training loop
			_loop_train_count = 1
			_loop_train()

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

	if apply_move:
		_simulations[0].move_hero(1.0, move_vector.angle(), _display_simulation)
		if _simulations[0].is_game_complete():
			_new_simulations()
			return

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return
	result = await _ai_tcp.init_agent(4, 2, 256, 40, 2, 3)
	_ai_tcp.load_agent(1)

func _get_batch_from_playing_round(simulations: Array[PCGSimulation], deterministic: bool) -> Array[Replay]:
	_new_simulations()
	var batch_replay: Array[Replay] = []
	var average_reward = 0
#
	for step in range(10):
		var scores_before: Array[float] = []
		var batch_state: Array = []
		for sim in simulations:
			var score_before = sim.get_score()
			scores_before.append(score_before)
			var state = sim.get_game_state()
			batch_state.append(state)

		var actions = await _ai_tcp.get_batch_actions(batch_state, deterministic)

		for simulation_index in range(simulations.size()):
			var sim = simulations[simulation_index]
			var action = actions[simulation_index] # Since we are not simulating in parallel, there is only 1 action
			sim.move_hero(action[1], action[0], null)
			var state_ = sim.get_game_state()
			var is_done = sim.is_game_complete()
			var score_after = sim.get_score()
			var reward = score_after - scores_before[simulation_index]
			if is_done:
				reward += 100
				sim.new_game()

			var replay = Replay.new(batch_state[simulation_index], action, reward, state_, is_done)

			batch_replay.append(replay)
			average_reward = reward
			if is_done:
				sim.new_game()

		_display_simulation(simulations[0])

	average_reward /= float(batch_replay.size())
	if deterministic:
		print("Average Reward: " + str(average_reward))

	return batch_replay

func _loop_train():
	if _is_loop_training:
		return

	_is_loop_training = true
	var replays = await _get_batch_from_playing_round(_simulations, false)
	var _response = await _ai_tcp.submit_batch_replay(replays)
	_response = await _ai_tcp.train(10, true, true)

	var average_reward = 0.0
	for replay in replays:
		average_reward += replay.reward
	average_reward /= float(replays.size())

	print("\n----------")
	print("Epoch: " + str(_loop_train_count))
	print("Average Reward: " + str(average_reward))
	_loop_train_count += 1

	_is_loop_training = false
	if Input.is_key_pressed(KEY_ENTER):
		return
	else:
		_loop_train()

func _display_simulation(sim: PCGSimulation):
	hero.position = sim.hero_position
	coin.position = sim.coin_position

func _new_simulations():
	if _simulations.is_empty():
		return
	for sim in _simulations:
		sim.new_game()

	_display_simulation(_simulations[0])

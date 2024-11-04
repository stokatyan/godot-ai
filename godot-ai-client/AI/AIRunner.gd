extends Node

class_name AIRunner

var env_delegate: AIBaseEnvironment

var _ai_tcp: AIServerTCP = AIServerTCP.new()

var _loop_train_count = 0
var _is_loop_training = false
var _is_testing = false

var _simulations: Array[BaseSimulation] = []

# Called when the node enters the scene tree for the first time.
func setup_simulations():
	for i in range(env_delegate.get_simulation_count()):
		_simulations.append(env_delegate.new_simulation())
	_reset_simulations()

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
			_reset_simulations()
		KEY_UP:
			_setup_ai()
		KEY_1: # Get and Apply action
			var current_state = _simulations[0].get_game_state()
			var start_time = Time.get_ticks_msec()
			var action = await _ai_tcp.get_action(current_state)
			var _time_elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
			_simulations[0].apply_action(action, env_delegate.display_simulation)
		KEY_2: # Get and Submit batch
			var replays = await _get_batch_from_playing_round(_simulations, false)
			var _response = await _ai_tcp.submit_batch_replay(replays)
		KEY_3: # Start training loop
			_loop_train_count = 1
			_loop_train()

func _reset_simulations():
	if _simulations.is_empty():
		return
	for sim in _simulations:
		sim.new_game()

	env_delegate.display_simulation(_simulations[0])

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return

	var state_dim = env_delegate.get_state_dim()
	var action_dim = env_delegate.get_action_dim()
	#batchsize: int, hidden_size: int, num_actor_layers: int, num_critic_layers: int
	var batch_size = env_delegate.get_batch_size()
	var num_actor_layers = env_delegate.get_num_actor_layers()
	var num_critic_layers = env_delegate.get_num_critic_layers()
	var hidden_size = env_delegate.get_hidden_size()
	result = await _ai_tcp.init_agent(state_dim, action_dim, batch_size, hidden_size, num_actor_layers, num_critic_layers)
	_ai_tcp.load_agent(1)

func _get_batch_from_playing_round(simulations: Array[BaseSimulation], deterministic: bool) -> Array[Replay]:
	_reset_simulations()
	var batch_replay: Array[Replay] = []
	var average_reward = 0
#
	for step in range(20):
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
			var action = actions[simulation_index]
			sim.apply_action(action, null)
			var state_ = sim.get_game_state()
			var is_done = sim.is_game_complete()
			var reward = sim.get_score()
			var replay = Replay.new(batch_state[simulation_index], action, reward, state_, is_done)

			batch_replay.append(replay)
			average_reward = reward
			if is_done:
				sim.new_game()

		env_delegate.display_simulation(simulations[0])

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
	_response = await _ai_tcp.train(env_delegate.get_train_steps(), true, true)

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

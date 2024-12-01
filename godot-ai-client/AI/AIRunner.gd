extends Node

class_name AIRunner

var env_delegate: AIBaseEnvironment

var _ai_tcp: AIServerTCP = AIServerTCP.new()

var _loop_train_count = 0
var _is_loop_training = false
var _is_testing = false

var _pending_hindsight_replays: Array[Replay] = []
var _simulations_used_in_hindsight_creation = {}

var _hindsight_creation_thread: Thread

var _initial_simulations: Array[BaseSimulation] = []

var _policy_agent: PolicyAgent

func _ready():
	add_child(_ai_tcp)
	_try_to_load_policy_agent()

# Called when the node enters the scene tree for the first time.
func setup_simulations():
	_initial_simulations = await _create_simulations()
	env_delegate.display_simulation(_initial_simulations[0])

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
			var simulations = await _create_simulations()
			var _result = await _get_batch_from_playing_round([simulations[0]], true)
			await get_tree().physics_frame
			await get_tree().physics_frame
			await get_tree().physics_frame
			await get_tree().physics_frame
			_cleanup_simulations(simulations)
			_is_testing = false
		KEY_UP:
			_setup_ai()
		KEY_1: # Get and Apply action
			if _initial_simulations.is_empty():
				return
			var current_state = _initial_simulations[0].get_game_state()
			var action: Array[float]
			if _policy_agent:
				action = _policy_agent.get_action(current_state, true)
			else:
				action = await _ai_tcp.get_action(env_delegate.get_agent_names()[0], current_state)

			_initial_simulations[0].apply_action(action, env_delegate.display_simulation)
		KEY_2: # Get and Submit batch
			env_delegate.update_status(_loop_train_count, "playing")
			var simulations = await _create_simulations()
			var replays = await _get_batch_from_playing_round(simulations, false)
			env_delegate.update_status(_loop_train_count, "submitting")
			var _response = await _ai_tcp.submit_batch_replay(replays)
			env_delegate.update_status(_loop_train_count, "done submitting")
			_cleanup_simulations(simulations)
		KEY_3: # Start training loop
			_loop_train_count = 1
			_loop_train()
		KEY_O:
			_ai_tcp.write_policy(env_delegate.get_agent_names()[0])
		KEY_N:
			_try_to_load_policy_agent()

func _try_to_load_policy_agent():
	print()
	print("Loading policy ...")
	var loader = PolicyLoader.new()
	loader.try_to_load_policy_data()
	if loader._did_load_policy_data:
		var _nn = NeuralNetwork.new(loader._policy_weights, loader._policy_biases)
		_policy_agent = PolicyAgent.new(_nn)
		print("Successfully loaded policy")
	if !_policy_agent:
		print("Failed to load policy")

func _create_simulations() -> Array[BaseSimulation]:
	env_delegate.update_status(_loop_train_count, "playing: _creating_simulations")

	var simulations: Array[BaseSimulation] = []

	for i in range(env_delegate.get_simulation_count()):
		var s = env_delegate.new_simulation()
		await s.new_game(get_tree().physics_frame)
		simulations.append(s)

	await get_tree().physics_frame
	await get_tree().physics_frame

	_cleanup_simulations(_initial_simulations)
	_initial_simulations = []

	return simulations

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return

	for agent_name in env_delegate.get_agent_names():
		var state_dim = env_delegate.get_state_dim(agent_name)
		var action_dim = env_delegate.get_action_dim(agent_name)
		var batch_size = env_delegate.get_batch_size(agent_name)
		var num_actor_layers = env_delegate.get_num_actor_layers(agent_name)
		var num_critic_layers = env_delegate.get_num_critic_layers(agent_name)
		var hidden_size = env_delegate.get_hidden_size(agent_name)
		result = await _ai_tcp.init_agent(agent_name, state_dim, action_dim, batch_size, hidden_size, num_actor_layers, num_critic_layers)
		_ai_tcp.load_agent(agent_name)
	_try_to_load_policy_agent()

func _get_batch_from_playing_round(simulations: Array[BaseSimulation], deterministic: bool) -> Array[Replay]:
	env_delegate.display_simulation(simulations[0])
	var batch_replay: Array[Replay] = []
	var done_indecis = {}
	var replay_history = {}
	for s in simulations:
		var history: Array[Replay] = []
		replay_history[s] = history

	for step in range(env_delegate.get_steps_in_round()):
		var scores_before: Array[float] = []
		var batch_state: Array = []

		var actions: Array = []
		for sim in simulations:
			var score_before = sim.get_score()
			scores_before.append(score_before)
			var state = sim.get_game_state()
			batch_state.append(state)

		if deterministic and _policy_agent and simulations.size() == 1:
			actions = [_policy_agent.get_action(batch_state[0], true)]
		else:
			env_delegate.update_status(_loop_train_count, "playing: get_batch_actions ...")
			actions = await _ai_tcp.get_batch_actions(batch_state, deterministic)
			env_delegate.update_status(_loop_train_count, "playing: got_batch_actions")

		for simulation_index in range(simulations.size()):
			if done_indecis.has(simulation_index):
				continue

			var sim = simulations[simulation_index]
			var action = actions[simulation_index]
			sim.apply_action(action, null)

		await get_tree().physics_frame
		await get_tree().physics_frame

		for simulation_index in range(simulations.size()):
			if done_indecis.has(simulation_index):
				continue

			var sim = simulations[simulation_index]
			var action = actions[simulation_index]
			var state_ = sim.get_game_state()
			var is_done = sim.is_game_complete()
			var reward = sim.get_score()
			var replay = Replay.new(batch_state[simulation_index], action, reward, state_, is_done)

			replay_history[sim].append(replay)

			if is_done:
				var replays = replay_history[sim]
				sim.rescore_history(replays)
				done_indecis[simulation_index] = true
				continue

		env_delegate.display_simulation(simulations[0])

	for simulation_index in range(simulations.size()):
		if done_indecis.has(simulation_index):
			continue
		var sim = simulations[simulation_index]
		var replays = replay_history[sim]
		sim.rescore_history(replays)

	batch_replay = _get_batch_replays_from_replay_map(replay_history)
	if !deterministic:
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		_create_hindsight_replays_on_bg_thread(simulations, done_indecis, replay_history)

	if deterministic:
		var average_reward = 0
		for replay in batch_replay:
			average_reward += replay.reward
		average_reward /= float(batch_replay.size())
		print("Test Reward: " + str(average_reward))

	return batch_replay

func _loop_train():
	if _is_loop_training:
		return

	print("\n----- Loop Train -----")
	print("Epoch: " + str(_loop_train_count))
	env_delegate.update_status(_loop_train_count, "playing")
	_is_loop_training = true
	var simulations = await _create_simulations()
	var replays = await _get_batch_from_playing_round(simulations, false)
	replays += _pending_hindsight_replays
	print("+ " + str(_pending_hindsight_replays.size()) + " hindsight replays appended")
	_pending_hindsight_replays = []
	print("Submitting ...")
	env_delegate.update_status(_loop_train_count, "submitting")
	var _response = await _ai_tcp.submit_batch_replay(replays)
	print("Training ...")
	env_delegate.update_status(_loop_train_count, "training")
	_response = await _ai_tcp.train(env_delegate.get_train_steps(), true, true)
	#_try_to_load_policy_agent()
	_cleanup_simulations(simulations)

	_loop_train_count += 1

	_is_loop_training = false
	if Input.is_key_pressed(KEY_ENTER):
		return
	else:
		_loop_train()

func _create_hindsight_replays_on_bg_thread(simulations: Array[BaseSimulation], done_indecis: Dictionary, replay_history: Dictionary):
	if _hindsight_creation_thread or simulations.is_empty():
		return

	for sim in simulations:
		_simulations_used_in_hindsight_creation[sim] = true
	_hindsight_creation_thread = Thread.new()
	_hindsight_creation_thread.start(_bg_thread_create_hindsight_replays.bind(simulations, done_indecis, replay_history))

func _bg_thread_create_hindsight_replays(simulations: Array[BaseSimulation], done_indecis: Dictionary, replay_history: Dictionary):
	var start_time = Time.get_ticks_msec()
	print("+ Creating hindsight replays ...")
	var hindsight_replays_history = {}
	for simulation_index in range(simulations.size()):
		if done_indecis.has(simulation_index):
			continue
		var sim = simulations[simulation_index]
		var replays = replay_history[sim]
		var hindsight_replays = await sim.create_hindsight_replays(replays, get_tree().physics_frame)
		hindsight_replays_history[sim] = hindsight_replays

	var batch_replays = _get_batch_replays_from_replay_map(hindsight_replays_history)
	print("++")
	print("+++ Created hindsight replays in " + str(float(Time.get_ticks_msec() - start_time) / 1000.0) + "s")
	print("++")

	call_deferred("_set_pending_hindsight_replays", batch_replays, simulations)

func _set_pending_hindsight_replays(batch_replay: Array[Replay], simulations: Array[BaseSimulation]):
	_pending_hindsight_replays += batch_replay
	_hindsight_creation_thread.wait_to_finish()
	_hindsight_creation_thread = null
	_simulations_used_in_hindsight_creation = {}
	_cleanup_simulations(simulations)

func _get_batch_replays_from_replay_map(replay_history: Dictionary) -> Array[Replay]:
	var batch_replay: Array[Replay] = []
	for r in replay_history.values():
		var replays: Array = r
		for replay in replays:
			batch_replay.append(replay)
	return batch_replay

func _cleanup_simulations(simulations: Array[BaseSimulation]):
	for sim in simulations:
		if !_simulations_used_in_hindsight_creation.has(sim):
			sim.cleanup_simulation()

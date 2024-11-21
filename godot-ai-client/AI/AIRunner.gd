extends Node

class_name AIRunner

var env_delegate: AIBaseEnvironment

var _ai_tcp: AIServerTCP = AIServerTCP.new()

var _loop_train_count = 0
var _is_loop_training = false
var _is_testing = false

var _simulations: Array[BaseSimulation] = []

var _pending_hindsight_replays: Array[Replay] = []
var _pending_hindsight_sim_to_display: BaseSimulation

var _hindsight_creation_thread: Thread

func _ready():
	add_child(_ai_tcp)

# Called when the node enters the scene tree for the first time.
func setup_simulations():
	for i in range(env_delegate.get_simulation_count()):
		_simulations.append(env_delegate.new_simulation())
	await _reset_simulations()
	env_delegate.display_simulation(_simulations[0])

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
		KEY_UP:
			_setup_ai()
		KEY_1: # Get and Apply action
			var current_state = _simulations[0].get_game_state()
			var start_time = Time.get_ticks_msec()
			var action = await _ai_tcp.get_action(current_state)
			var _time_elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
			_simulations[0].apply_action(action, env_delegate.display_simulation)
		KEY_2: # Get and Submit batch
			env_delegate.update_status(_loop_train_count, "playing")
			var replays = await _get_batch_from_playing_round(_simulations, false)
			env_delegate.update_status(_loop_train_count, "submitting")
			var _response = await _ai_tcp.submit_batch_replay(replays)
			env_delegate.update_status(_loop_train_count, "done submitting")
		KEY_3: # Start training loop
			_loop_train_count = 1
			_loop_train()

func _reset_simulations() -> bool:
	if _simulations.is_empty():
		return false

	var num_old_sims = _simulations.size()
	_simulations = []

	for i in range(num_old_sims):
		var s = env_delegate.new_simulation()
		await s.new_game(get_tree().physics_frame)
		_simulations.append(s)

	return true

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return

	var state_dim = env_delegate.get_state_dim()
	var action_dim = env_delegate.get_action_dim()
	var batch_size = env_delegate.get_batch_size()
	var num_actor_layers = env_delegate.get_num_actor_layers()
	var num_critic_layers = env_delegate.get_num_critic_layers()
	var hidden_size = env_delegate.get_hidden_size()
	result = await _ai_tcp.init_agent(state_dim, action_dim, batch_size, hidden_size, num_actor_layers, num_critic_layers)
	_ai_tcp.load_agent(1)

func _get_batch_from_playing_round(simulations: Array[BaseSimulation], deterministic: bool) -> Array[Replay]:
	env_delegate.update_status(_loop_train_count, "playing: _reset_simulations")
	await _reset_simulations()
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
		for sim in simulations:
			var score_before = sim.get_score()
			scores_before.append(score_before)
			var state = sim.get_game_state()
			batch_state.append(state)

		env_delegate.update_status(_loop_train_count, "playing: get_batch_actions ...")
		var actions = await _ai_tcp.get_batch_actions(batch_state, deterministic)
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

	if !deterministic:
		_create_hindsight_replays_on_bg_thread(simulations, done_indecis, replay_history)

	batch_replay = _get_batch_replays_from_replay_map(replay_history)

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
	var replays = await _get_batch_from_playing_round(_simulations, false)
	replays += _pending_hindsight_replays
	_pending_hindsight_replays = []
	if _pending_hindsight_sim_to_display:
		env_delegate.display_simulation(_pending_hindsight_sim_to_display)
	print("Submitting ...")
	env_delegate.update_status(_loop_train_count, "submitting")
	var _response = await _ai_tcp.submit_batch_replay(replays)
	print("Training ...")
	env_delegate.update_status(_loop_train_count, "training")
	_response = await _ai_tcp.train(env_delegate.get_train_steps(), true, true)

	var average_reward = 0.0
	for replay in replays:
		average_reward += replay.reward
	average_reward /= float(replays.size())

	print("Average Reward: " + str(average_reward))
	_loop_train_count += 1

	_is_loop_training = false
	if Input.is_key_pressed(KEY_ENTER):
		return
	else:
		_loop_train()

func _create_hindsight_replays_on_bg_thread(simulations: Array[BaseSimulation], done_indecis: Dictionary, replay_history: Dictionary):
	if _hindsight_creation_thread or simulations.is_empty():
		return

	_hindsight_creation_thread = Thread.new()
	_hindsight_creation_thread.start(_bg_thread_create_hindsight_replays.bind(simulations, done_indecis, replay_history))

func _bg_thread_create_hindsight_replays(simulations: Array[BaseSimulation], done_indecis: Dictionary, replay_history: Dictionary) -> BaseSimulation:
	var start_time = Time.get_ticks_msec()
	print("Creating hindsight replays ...")
	var hindsight_replays_history = {}
	for simulation_index in range(simulations.size()):
		if done_indecis.has(simulation_index):
			continue
		var sim = simulations[simulation_index]
		var replays = replay_history[sim]
		var hindsight_replays = await sim.create_hindsight_replays(replays, get_tree().physics_frame)
		hindsight_replays_history[sim] = hindsight_replays

	var batch_replays = _get_batch_replays_from_replay_map(hindsight_replays_history)
	print("___")
	print("Created hindsight replays in " + str(float(Time.get_ticks_msec() - start_time) / 1000.0) + "s")
	print("___")

	call_deferred("_set_pending_hindsight_replays", batch_replays)
	return simulations[0]

func _set_pending_hindsight_replays(batch_replay: Array[Replay]):
	_pending_hindsight_replays += batch_replay
	if _hindsight_creation_thread.is_alive():
		_pending_hindsight_sim_to_display = _hindsight_creation_thread.wait_to_finish()
	_hindsight_creation_thread = null

func _get_batch_replays_from_replay_map(replay_history: Dictionary) -> Array[Replay]:
	var batch_replay: Array[Replay] = []
	for r in replay_history.values():
		var replays: Array = r
		for replay in replays:
			batch_replay.append(replay)
	return batch_replay

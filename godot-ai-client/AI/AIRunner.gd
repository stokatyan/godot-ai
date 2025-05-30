extends Node

class_name AIRunner

var env_delegate: AIBaseEnvironment

var _ai_tcp: AIServerTCP = AIServerTCP.new()

var _loop_train_count = 1
var _is_loop_training = false

var _pending_hindsight_replays: Array[Replay] = []
var _simulations_used_in_hindsight_creation = {}

var _hindsight_creation_thread: Thread

var _initial_simulations: Array[BaseSimulation] = []

var _policy_agents: Array[PolicyAgent]

func _ready():
	add_child(_ai_tcp)
	_try_to_load_policy_agents()

# Called when the node enters the scene tree for the first time.
func setup_simulations():
	_initial_simulations = await _create_simulations()

	for i in range(0, env_delegate.get_number_of_simulations_to_display()):
		env_delegate.display_simulation(_initial_simulations[i])

func _input(event):
	var key_input = event as InputEventKey
	if !key_input:
		return

	if key_input.echo or key_input.is_released():
		return
	match key_input.keycode:
		KEY_UP:
			_setup_ai()
		KEY_2: # Get and Submit batch
			env_delegate.update_status(_loop_train_count, "playing")
			var simulations = await _create_simulations()
			var is_discrete_map = {}
			for agent_name in env_delegate.get_agent_names():
				is_discrete_map[agent_name] = true

			var replays = await _get_batch_from_playing_round(env_delegate.get_steps_in_round(), simulations, is_discrete_map)
			env_delegate.update_status(_loop_train_count, "submitting")
			var _response = await _ai_tcp.submit_batch_replay(replays)
			env_delegate.update_status(_loop_train_count, "done submitting")
			_cleanup_simulations(simulations)
		KEY_3: # Start training loop
			if _is_loop_training:
				return
			_is_loop_training = true
			_loop_train()
		KEY_O:
			_ai_tcp.write_policy(env_delegate.get_agent_names()[0])
		KEY_ENTER:
			_is_loop_training = false

func _try_to_load_policy_agents():
	print()
	print("Loading policy ...")
	for agent_name in env_delegate.get_agent_names():
		var loader = PolicyLoader.new()
		loader.try_to_load_policy_data(agent_name)
		if loader._did_load_policy_data:
			var _nn = NeuralNetwork.new(loader._policy_weights, loader._policy_biases)
			var _policy_agent = PolicyAgent.new(_nn)

			if !_policy_agent:
				print("Failed to load policy")
			else:
				print("Successfully loaded policy")

func _create_simulations() -> Array[BaseSimulation]:
	env_delegate.update_status(_loop_train_count, "playing: _creating_simulations")

	var simulations: Array[BaseSimulation] = []

	for i in range(env_delegate.get_simulation_count()):
		var s = env_delegate.new_simulation()
		var result = await s.new_game(get_tree().physics_frame)
		simulations.append(s)

	await get_tree().physics_frame
	await get_tree().physics_frame

	_cleanup_simulations(_initial_simulations)
	_initial_simulations = []

	env_delegate.update_status(_loop_train_count, "playing: done creating_simulations")

	return simulations

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return

	var agent_names = env_delegate.get_agent_names()
	for agent_name in agent_names:
		var state_dim = env_delegate.get_state_dim(agent_name)
		var action_dim = env_delegate.get_action_dim(agent_name)
		var batch_size = env_delegate.get_batch_size(agent_name)
		var num_actor_layers = env_delegate.get_num_actor_layers(agent_name)
		var num_critic_layers = env_delegate.get_num_critic_layers(agent_name)
		var hidden_size = env_delegate.get_hidden_size(agent_name)
		var replay_capacity = env_delegate.get_replay_capacity(agent_name)
		result = await _ai_tcp.init_agent(agent_name, state_dim, action_dim, batch_size, hidden_size, num_actor_layers, num_critic_layers, replay_capacity)
		result = await _ai_tcp.load_agent(agent_name)

func _get_batch_from_playing_round(steps: int, simulations: Array[BaseSimulation], deterministic_map: Dictionary) -> Array[Replay]:
	for i in range(0, env_delegate.get_number_of_simulations_to_display()):
		env_delegate.display_simulation(simulations[i])

	var batch_replay: Array[Replay] = []
	var done_indecis: Array[Dictionary] = []
	var replay_history = {}
	for s in simulations:
		var history: Array[Replay] = []
		replay_history[s] = history
		var index_to_done_map = {}
		for index in s.get_agents_count():
			index_to_done_map[index] = false

		done_indecis.append(index_to_done_map)

	for step in range(steps):
		var agent_to_move_index = {}
		var agent_to_states_map = {}
		for simulation_index in range(simulations.size()):
			var sim = simulations[simulation_index]
			for agent_index in sim.get_agents_count():
				if done_indecis[simulation_index][agent_index]:
					continue
				var agent_name = sim.get_agent_name(agent_index)
				agent_to_move_index[agent_name] = 0
				var state = sim.get_state(agent_index)
				var batch_state: Array = []
				if agent_to_states_map.has(agent_name):
					batch_state = agent_to_states_map[agent_name]
				batch_state.append(state)
				agent_to_states_map[agent_name] = batch_state

		var actions_dictionary = {}
		env_delegate.update_status(_loop_train_count, "playing: get_batch_actions ...")
		actions_dictionary = await _ai_tcp.get_batch_actions(agent_to_states_map, deterministic_map)
		env_delegate.update_status(_loop_train_count, "playing: got_batch_actions")

		for simulation_index in range(simulations.size()):
			var sim = simulations[simulation_index]
			for agent_index in sim.get_agents_count():
				if done_indecis[simulation_index][agent_index]:
					continue
				var agent_name = sim.get_agent_name(agent_index)
				var agent_move_index = agent_to_move_index[agent_name]
				agent_to_move_index[agent_name] = agent_move_index + 1
				var action = actions_dictionary[agent_name][agent_move_index]
				sim.apply_action(agent_index, action, null)

		await get_tree().physics_frame
		await get_tree().physics_frame

		for key in agent_to_move_index.keys():
			agent_to_move_index[key] = 0

		for simulation_index in range(simulations.size()):
			var sim = simulations[simulation_index]

			for agent_index in sim.get_agents_count():
				if done_indecis[simulation_index][agent_index]:
					continue
				var agent_name = sim.get_agent_name(agent_index)

				var is_done = sim.is_game_complete(agent_index)
				if deterministic_map.has(agent_name) and deterministic_map[agent_name]:
					continue

				# Get the index of of the move
				var agent_move_index = agent_to_move_index[agent_name]

				# Create Replay
				var state_ = sim.get_state(agent_index)
				var action = actions_dictionary[agent_name][agent_move_index]
				var reward = sim.get_score(agent_index)
				var prev_state = agent_to_states_map[agent_name][agent_move_index]
				var replay = Replay.new(prev_state, action, reward, state_, is_done)
				replay.agent_name = agent_name
				replay_history[sim].append(replay)
				agent_to_move_index[agent_name] = agent_move_index + 1

				if is_done:
					done_indecis[simulation_index][agent_index] = true
					continue

		for i in range(0, env_delegate.get_number_of_simulations_to_display()):
			env_delegate.display_simulation(simulations[i])

	batch_replay = _get_batch_replays_from_replay_map(replay_history)

	await get_tree().physics_frame
	await get_tree().physics_frame

	return batch_replay

func _loop_train():
	if !_is_loop_training:
		return

	print("\n----- Loop Train -----")
	print("Epoch: " + str(_loop_train_count))
	env_delegate.update_status(_loop_train_count, "playing")
	var simulations = await _create_simulations()
	var is_deterministic_map = env_delegate.get_is_deterministic_map(_loop_train_count)
	var replays = await _get_batch_from_playing_round(env_delegate.get_steps_in_round(), simulations, is_deterministic_map)
	print("Submitting ...")
	env_delegate.update_status(_loop_train_count, "submitting")
	var _response = await _ai_tcp.submit_batch_replay(replays)
	print("Training ...")
	env_delegate.update_status(_loop_train_count, "training")
	for agent_name in env_delegate.get_agent_names():
		if !is_deterministic_map.has(agent_name) or !is_deterministic_map[agent_name]:
			var checkpoint_name = agent_name
			if _loop_train_count % 1000 == 0:
				checkpoint_name += "_" + str(_loop_train_count)
			_response = await _ai_tcp.train(agent_name, env_delegate.get_train_steps(agent_name), true, checkpoint_name)
	_cleanup_simulations(simulations)
	print("Done Training")
	env_delegate.update_status(_loop_train_count, "Done Training")
	_loop_train_count += 1

	_loop_train()

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

This is the project that powered the AI agents shown in the gif below, which made it to top 5 in the all time posts on [r/reinforcementlearning](https://www.reddit.com/r/reinforcementlearning/comments/1hawyj5/2_ai_agents_playing_hide_and_seek_after_15/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button)

![gif](https://github.com/stokatyan/ReadMeMedia/blob/master/godot-ai-example.gif)

# About This Project
This project enables the creation of environments in Godot that utilize agents powered by PyTorch for decision-making and reinforcement learning.

This repository streamlines reinforcement learning by handling several intricate aspects of AI in game development, including:

- Running multiple scenes in parallel (sort of) while allowing physics calculations between agent steps.
- Sending observations to a Python application, enabling integration with PyTorch.
- Batching observations for efficient GPU processing.
- Parsing batched actions from PyTorch and ensuring they are applied correctly to the corresponding scene and agent in Godot.
- Configuring AI models directly from the Godot scene, eliminating the need for manual updates to PyTorch layers across different scenes.

### Parallel Environments
Reinforcement learning agents need to train in parallel environments to optimize learning time.
In `godot-ai`, a scene containing the "game" is created in Godot and derives from `AIBaseEnvironment`, which utilizes an `AIRunner` to handle stepping through scenes in parrallel while also wiaitng for physics calculations from the engine to complete.

The `AIRunner` can be best understood from this snippet of it's implementation:
```gdscript
func _loop_train():
	if !_is_loop_training:
		return

	print("\n----- Loop Train -----")
	print("Epoch: " + str(_loop_train_count))
	env_delegate.update_status(_loop_train_count, "playing")
	var simulations = await _create_simulations() # Create the simulations that will run on a seperate thread, and will have their observations batched.
	var is_deterministic_map = env_delegate.get_is_deterministic_map(_loop_train_count) # Set which agents are training, and which should be deterministic.

  # Play 1 round
  # A round has n steps (an AIBaseEnvironment param), where all agents make a step in each round.
  # In each step, an observation is made for each agent and then sent to PyTorch.
  # After Godot gets the batch of actions, it applies the actions, and creates a batch of replays.
	var replays = await _get_batch_from_playing_round(env_delegate.get_steps_in_round(), simulations, is_deterministic_map)
	print("Submitting ...")
	env_delegate.update_status(_loop_train_count, "submitting")

  # The batched replays are sent to PyTorch so they can be used for training.
	var _response = await _ai_tcp.submit_batch_replay(replays)
	print("Training ...")
	env_delegate.update_status(_loop_train_count, "training")

  # Command PyTorch to train each agent, and then save the checkpoint.
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

	_loop_train() # Train until stopped.
```

### Sending Data between Godot and Python



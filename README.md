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
The "games" which are run in parrallel derive from `BaseSimulation`, which the `AIRunner` interfaces with when stepping through each game.

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
Godot and Python cannot communicate directly.  Instead, Godot launches the python app defined in `/ai-server/ai_server.py`, and communicates with it using TCP.
TCP, however, is not ideal for the large amount of data that needs to be sent. As a result, TCP is used just to communicate instructions, but data is expected to be written and read from at `godot-ai\godot-ai-client\AIServerCommFiles` (this folder and its files are not ignored by the project).

## Getting Started
To get started, you can run the FCGEnv.scene to reproduce the gif above.
All you will need is Godot4 (with GDScript, not C#) and Pytorch (I am using 2.4.1+cu124).

1. Launch the Godot Project
2. Open the scene `res://FindCoinGame/FCGEnv.tscn`
3. Run the open scene (note, the default scene is `res://ZombieGame/ZEnv.tscn`, which can also be run).
4. Wait a moment, you should see a terminal open and after a second or two you should see the following:
```
Current working directory: C:\Users\<user>\Git\godot-ai\godot-ai-client
AI Server is waiting for a connection...
```
5. Click on the Godot scene that was launched (so it is listening to keyboard input).
6. Press up arrow on your keyboard, the python shell should output the following:
```
Connection from ('127.0.0.1', <some numbers>)
Replay Capacity: 100000 
Agent named hero initialized.
Checkpoint loaded for checkpoints/hero.pt
Replay Capacity: 100000
Agent named target initialized.
Checkpoint loaded for checkpoints/target.pt
```
7a. Press Numpad_2 to see both agents in deterministic mode
<OR>
7b. Press Numpad_3 to start training.

## Notes:
- Although hundreds of scenes can run in parrallel, only 3 are shown in the predefined environments.  Override `AIBaseEnvironment`'s `func display_simulation(_simulation: BaseSimulation):` to customize how the environment displays simulations.
- To toggle whether an agent is training, or needs to be in determinstic mode, override `func get_is_deterministic_map(epoch: int) -> Dictionary:`.
   - If you did step 7b., then you can toggle agent training states by pressing numpad_7, numpad_8, numpad_9, or numpad_0 (see lines [46-62](https://github.com/stokatyan/godot-ai/blob/475c6e18fe969456efcb787b39df2ebdd0694711/godot-ai-client/FindCoinGame/FCGEnv.gd#L46) for an example of how toggling training states works)

## Contact
If you have any questions, feel free to email reach me at:
`tokat.shant@gmail.com`
[@stokatyan](https://x.com/STokatyan)

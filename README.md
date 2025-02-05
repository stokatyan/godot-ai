This is the project that powered the AI agents shown in the gif below, which made it to top 5 in the all time posts on [r/reinforcementlearning](https://www.reddit.com/r/reinforcementlearning/comments/1hawyj5/2_ai_agents_playing_hide_and_seek_after_15/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button)

![gif](https://github.com/stokatyan/ReadMeMedia/blob/master/godot-ai-example.gif)

# About This Project
This project enables the creation of environments in Godot that utilize agents powered by PyTorch for decision-making and reinforcement learning.

This repository streamlines reinforcement learning by handling several intricate aspects of AI in game development, including:

- Running multiple scenes in parallel while allowing physics calculations between agent steps.
- Sending observations to a Python application, enabling integration with PyTorch.
- Batching observations for efficient GPU processing.
- Parsing batched actions from PyTorch and ensuring they are applied correctly to the corresponding scene and agent in Godot.
- Configuring AI models directly from the Godot scene, eliminating the need for manual updates to PyTorch layers across different scenes.

### Parallel Environments
Reinforcement learning agents need to train in parallel environments to optimize learning time.
In `godot-ai`, a scene containing the "game" is created in Godot and derives from `AIBaseEnvironment`, which utilizes an `AIRunner` to handle stepping through scenes in parrallel while also wiaitng for physics calculations from the engine to complete.

### Sending Data between Godot and Python

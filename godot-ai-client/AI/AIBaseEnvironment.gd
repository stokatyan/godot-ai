extends Node

class_name AIBaseEnvironment

func new_simulation() -> BaseSimulation:
	return BaseSimulation.new()

func display_simulation(simulation: BaseSimulation):
	pass

func get_simulation_count() -> int:
	return 1

func get_state_dim() -> int:
	return 0

func get_action_dim() -> int:
	return 0

func get_batch_size() -> int:
	return 0

func get_num_actor_layers() -> int:
	return 0

func get_num_critic_layers() -> int:
	return 0

func get_hidden_size() -> int:
	return 0

func get_train_steps() -> int:
	return 0

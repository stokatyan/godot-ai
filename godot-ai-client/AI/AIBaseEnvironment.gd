extends CanvasItem

class_name AIBaseEnvironment

var _ai_runner = AIRunner.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	_ai_runner.env_delegate = self
	add_child(_ai_runner)
	_ai_runner.setup_simulations()

func new_simulation() -> BaseSimulation:
	return BaseSimulation.new()

func display_simulation(_simulation: BaseSimulation):
	pass

func get_steps_in_round() -> int:
	return 20

func get_simulation_count() -> int:
	return 1

func get_state_dim(agent_name: String) -> int:
	return 0

func get_action_dim(agent_name: String) -> int:
	return 0

func get_batch_size(agent_name: String) -> int:
	return 0

func get_num_actor_layers(agent_name: String) -> int:
	return 0

func get_num_critic_layers(agent_name: String) -> int:
	return 0

func get_hidden_size(agent_name: String) -> int:
	return 0

func get_train_steps(agent_name: String) -> int:
	return 0

func update_status(_epoch: int, _message: String):
	pass

func get_agent_names() -> Array[String]:
	var agent_names: Array[String] = []
	return agent_names

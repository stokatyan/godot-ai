extends CanvasItem

class_name AIBaseEnvironment

var _ai_runner = AIRunner.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	_ai_runner.env_delegate = self
	add_child(_ai_runner)
	_ai_runner.setup_simulations()

func get_number_of_simulations_to_display() -> int:
	return 1

func new_simulation() -> BaseSimulation:
	assert(false, "new_simulation not implemented")
	return BaseSimulation.new()

func display_simulation(_simulation: BaseSimulation):
	assert(false, "display_simulation not implemented")

func get_steps_in_round() -> int:
	assert(false, "get_steps_in_round not implemented")
	return 20

func get_simulation_count() -> int:
	assert(false, "get_steps_in_round not implemented")
	return 1

func get_state_dim(_agent_name: String) -> int:
	assert(false, "get_steps_in_round not implemented")
	return 0

func get_action_dim(_agent_name: String) -> int:
	assert(false, "get_steps_in_round not implemented")
	return 0

func get_batch_size(_agent_name: String) -> int:
	assert(false, "get_steps_in_round not implemented")
	return 0

func get_num_actor_layers(_agent_name: String) -> int:
	assert(false, "get_steps_in_round not implemented")
	return 0

func get_num_critic_layers(_agent_name: String) -> int:
	assert(false, "get_steps_in_round not implemented")
	return 0

func get_hidden_size(_agent_name: String) -> int:
	assert(false, "get_steps_in_round not implemented")
	return 0

func get_replay_capacity(_agent_name) -> int:
	assert(false)
	return 0

func get_train_steps(_agent_name: String) -> int:
	assert(false, "get_steps_in_round not implemented")
	return 0

func update_status(_epoch: int, _message: String):
	pass

func get_agent_names() -> Array[String]:
	assert(false, "get_steps_in_round not implemented")
	var agent_names: Array[String] = []
	return agent_names

func get_is_deterministic_map(epoch: int) -> Dictionary:
	assert(false, "get_is_discrete_map not implemented")
	var deterministic_map = {}
	return deterministic_map

func get_agent_indecis() -> Array[int]:
	assert(false)
	var indecis: Array[int] = []
	return indecis

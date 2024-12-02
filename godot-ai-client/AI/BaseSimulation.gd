extends RefCounted

class_name BaseSimulation

var _is_cleaned = false

func new_game(physics_update: Signal) -> bool:
	assert(false)
	await physics_update
	return true

func is_game_complete(_agent_index: int) -> bool:
	assert(false)
	return false

func apply_action(_agent_index: int, _action_vector: Array[float], _callback):
	assert(false)
	pass

func get_state(_agent_index: int) -> Array[float]:
	assert(false)
	return []

func get_score(_agent_index: int) -> float:
	assert(false)
	return 0

func cleanup_simulation():
	_is_cleaned = true

func get_state_dim(_agent_name: String) -> int:
	assert(false)
	return 0

func get_action_dim(_agent_name: String) -> int:
	assert(false)
	return 0

func get_agent_names() -> Array[String]:
	assert(false)
	var agent_names = []
	return agent_names

func get_agents_count() -> int:
	assert(false)
	return 0

func get_agent_name(_agent_index: int) -> String:
	assert(false)
	return ""

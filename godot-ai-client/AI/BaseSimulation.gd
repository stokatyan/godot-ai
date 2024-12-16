extends RefCounted

class_name BaseSimulation

var _is_cleaned = false

func new_game(physics_update: Signal) -> bool:
	assert(false, "new_game not implemented not implemented")
	await physics_update
	return true

func is_game_complete(_agent_index: int) -> bool:
	assert(false, "is_game_complete not implelented not implemented")
	return false

func apply_action(_agent_index: int, _action_vector: Array[float], _callback):
	assert(false, "apply_action not implemented")
	pass

func get_state(_agent_index: int) -> Array[float]:
	assert(false, "get_state not implemented")
	return []

func get_score(_agent_index: int) -> float:
	assert(false, "get_score not implemented")
	return 0

func cleanup_simulation():
	assert(false, "cleanup_simulation not implemented")

func get_state_dim(_agent_name: String) -> int:
	assert(false, "get_state_dim not implemented")
	return 0

func get_action_dim(_agent_name: String) -> int:
	assert(false, "get_action_dim not implemented")
	return 0

func get_agent_names() -> Array[String]:
	assert(false, "get_agent_names not implemented")
	var agent_names = []
	return agent_names

func get_agents_count() -> int:
	assert(false, "get_agents_count not implemented")
	return 0

func get_agent_name(_agent_index: int) -> String:
	assert(false, "get_agent_name not implemented")
	return ""

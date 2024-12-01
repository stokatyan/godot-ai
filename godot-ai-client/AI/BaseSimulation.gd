extends RefCounted

class_name BaseSimulation

var _is_cleaned = false

func new_game(physics_update: Signal) -> bool:
	await physics_update
	return true

func is_game_complete() -> bool:
	return false

func apply_action(agent_index: int, _action_vector: Array[float], _callback):
	pass

func get_observation(agent_index: int) -> Array[float]:
	return []

func get_score(agent_index: int) -> float:
	return 0

func cleanup_simulation():
	_is_cleaned = true

func get_agent_names() -> Array[String]:
	var agent_names = []
	return agent_names

func get_agent_name(agent_index: int) -> String:
	return ""

func get_state_dim(agent_name: String) -> int:
	return 0

func get_action_dim(agent_name: String) -> int:
	return 0

func get_agent_indicis() -> Array[int]:
	var indicis: Array[int] = []
	return indicis

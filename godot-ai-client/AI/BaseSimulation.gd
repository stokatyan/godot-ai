extends RefCounted

class_name BaseSimulation

var _is_cleaned = false

func new_game(physics_update: Signal) -> bool:
	await physics_update
	return true

func is_game_complete() -> bool:
	return false

func apply_action(_action_vector: Array[float], _callback):
	pass

func get_game_state() -> Array[float]:
	return []

func get_score() -> float:
	return 0

func rescore_history(_history: Array[Replay]):
	pass

func create_hindsight_replays(_history: Array[Replay], physics_update_signal = null) -> Array[Replay]:
	var hindsight_replays: Array[Replay] = []
	if physics_update_signal:
		await physics_update_signal
	return hindsight_replays

func cleanup_simulation():
	_is_cleaned = true

func get_agent_names() -> Array[String]:
	var agent_names = []
	return agent_names

func get_state_dim(agent_name: String) -> int:
	return 0

func get_action_dim(agent_name: String) -> int:
	return 0

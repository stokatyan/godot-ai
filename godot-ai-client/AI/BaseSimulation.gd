extends RefCounted

class_name BaseSimulation

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

func rescore_history(history: Array[Replay]):
	pass

func create_hindsight_replays(history: Array[Replay]) -> Array[Replay]:
	var hindsight_replays: Array[Replay] = []
	return hindsight_replays

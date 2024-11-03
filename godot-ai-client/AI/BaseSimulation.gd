extends RefCounted

class_name BaseSimulation

func new_game():
	pass

func is_game_complete() -> bool:
	return false

func apply_action(action_vector: Array[float], callback):
	pass

func get_game_state() -> Array[float]:
	return []

func get_score() -> float:
	return 0

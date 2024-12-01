extends RefCounted

class_name Replay

var state: Array[float]
var action: Array[float]
var reward: float
var state_: Array[float]
var done: int
var agent_name: String = ""

var rounding_precision = 0.0001

func _init(_state: Array[float], _action: Array[float], _reward: float, _state_: Array[float], _done: bool):
	state = []
	for s in _state:
		state.append(snappedf(s, rounding_precision))

	action = []
	for a in _action:
		action.append(snappedf(a, rounding_precision))

	reward = snappedf(_reward, rounding_precision)

	state_ = []
	for s in _state_:
		state_.append(snappedf(s, rounding_precision))

	done = 0
	if _done:
		done = 1

func to_data() -> Dictionary:
	var data = {}

	data["state"] = state
	data["action"] = action
	data["reward"] = reward
	data["state_"] = state_
	data["done"] = done

	if agent_name.length() > 0:
		data["agent_name"] = agent_name

	return data

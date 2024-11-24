extends RefCounted

class_name PolicyAgent

var _nn: NeuralNetwork

func _init(nn: NeuralNetwork):
	_nn = nn

func get_action(input: Array[float]) -> Array[float]:
	return _nn.feed_forward(input)

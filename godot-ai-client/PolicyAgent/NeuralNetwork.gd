extends RefCounted

class_name NeuralNetwork

var _weights: Array
var _biases: Array

func _init(weights: Array, biases: Array):
	_weights = weights
	_biases = biases
	if _weights.size() != _biases.size():
		push_error("Expected weights and biases to have same size.")

func feed_forward(input: Array[float]) -> Array[float]:
	print("--input--------")
	print(input)
	var output = [input]
	var _weights_size = _weights.size()
	for i in range(_weights.size()):
		var w = _weights[i]
		var b = _biases[i]
		var apply_activation = i != _weights.size() - 1
		output = _process_layer(output, w, b, apply_activation)

	var actions: Array[float] = []
	for i in output[0]:
		actions.append(output[0][i] as float)

	return actions

func _process_layer(input_matrix: Array, weights: Array, bias: Array, apply_activation: bool) -> Array:
	var output = _matmul(input_matrix, weights)  # Matrix multiplication
	for i in range(output.size()):  # Add bias to each row
		for j in range(output[i].size()):
			output[i][j] += bias[j]

	if apply_activation:
		return _relu(output)  # Apply ReLU activation
	else:
		return output

func _matmul(A: Array, B: Array) -> Array:
	var result = []
	for i in range(A.size()):
		var row = []
		for j in range(B.size()):
			var value = 0
			for k in range(A[0].size()):
				value += A[i][k] * B[j][k]
			row.append(value)
		result.append(row)
	return result

func _relu(matrix: Array) -> Array:
	var result = []
	for row in matrix:
		var new_row = []
		for value in row:
			new_row.append(max(0, value))  # ReLU: max(0, x)
		result.append(new_row)
	return result

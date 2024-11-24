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
	var output = [input]
	var _weights_size = _weights.size()
	for i in range(_weights.size()):
		var w = _weights[i]
		var b = _biases[i]
		output = _process_layer(output, w, b)
	return output

func _process_layer(input_matrix: Array, weights: Array, bias: Array) -> Array:
	var output = _matmul(input_matrix, weights)  # Matrix multiplication
	for i in range(output.size()):  # Add bias to each row
		for j in range(output[i].size()):
			output[i][j] += bias[j]
	return _relu(output)  # Apply ReLU activation

func _matmul(A: Array, B: Array) -> Array:
	var result = []
	for i in range(A.size()):
		var row = []
		for j in range(B[0].size()):
			var value = 0
			for k in range(A[0].size()):
				value += A[i][k] * B[k][j]
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

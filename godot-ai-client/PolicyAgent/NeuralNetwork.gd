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
		var apply_activation = i != _weights.size() - 1
		output = _process_layer(output, w, b, apply_activation)

	var actions: Array[float] = []
	for value in output[0]:
		actions.append(value as float)

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

func _matmul(A: Array, B_: Array) -> Array:
	var B = _transpose(B_)
	# Validate matrix dimensions
	if A.size() == 0 or B.size() == 0:
		push_error("Matrix dimensions are invalid. A or B is empty.")
		return []
	if A[0].size() != B.size():
		push_error("Matrix dimensions do not match for multiplication.")
		return []

	var result = []
	for i in range(A.size()):  # Rows of A
		var row = []
		for j in range(B[0].size()):  # Columns of B
			var value = 0
			for k in range(A[0].size()):  # Columns of A / Rows of B
				value += A[i][k] * B[k][j]
			row.append(value)
		result.append(row)
	return result

func _transpose(B: Array) -> Array:
	if B.size() == 0:
		return []  # Handle empty input gracefully

	var transposed = []
	for j in range(B[0].size()):  # Iterate over columns of B
		var row = []
		for i in range(B.size()):  # Iterate over rows of B
			row.append(B[i][j])  # Append the element at (i, j) to the transposed row
		transposed.append(row)
	return transposed

func _relu(matrix: Array) -> Array:
	var result = []
	for row in matrix:
		var new_row = []
		for value in row:
			new_row.append(max(0, value))  # ReLU: max(0, x)
		result.append(new_row)
	return result

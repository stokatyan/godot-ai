extends RefCounted

class_name PolicyLoader

var _did_load_policy_data = false

var _policy_weights: Array
var _policy_biases: Array

func get_policy_path(file_name: String) -> String:
	return "res://AIServerCommFiles/" + file_name + ".json"

func try_to_load_policy_data(file_name: String):
	var policy_path = get_policy_path(file_name)
	if FileAccess.file_exists(policy_path):
		var file = FileAccess.open(policy_path, FileAccess.READ)
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)

		if error == OK:
			var json_data = json.data
			if typeof(json_data) == TYPE_DICTIONARY:
				_set_policy_data(json_data)
			else:
				print("Unexpected data when parsing json")
	else:
		print("Policy File does not exist: ", policy_path)

func _set_policy_data(json_data: Dictionary):
	_did_load_policy_data = false
	_policy_weights.clear()
	_policy_biases.clear()

	var keys: Array[String] = []

	for k in json_data.keys():
		keys.append(k as String)

	keys.sort_custom(_compare_numerical_suffix)

	var i = 0
	while i < keys.size():
		var k_weight = keys[i]
		var k_bias = keys[i + 1]
		var weights: Array = json_data[k_weight]
		var biases: Array = json_data[k_bias]
		var weights_size = weights.size()
		_policy_weights.append(weights)
		_policy_biases.append(biases)
		i += 2

	_did_load_policy_data = true

# Custom comparison function
func _compare_numerical_suffix(a: String, b: String) -> int:
	# Extract the numerical suffix after the dot
	var num_a = int(a.split(".")[2])
	var num_b = int(b.split(".")[2])
	# Compare the numeric values
	return num_a < num_b

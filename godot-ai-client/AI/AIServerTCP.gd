extends Node

class_name AIServerTCP

var _client : StreamPeerTCP

var _is_communicating = false:
	set(value):
		_is_communicating = value

var _python_thread = Thread.new()

var rounding_precision = 0.0001

func _ready():
	_python_thread.start(_launch_python_ai_server)

func attempt_connection_to_ai_server() -> bool:
	if _client:
		return false
	_client = StreamPeerTCP.new()

	# Connect to the Python server running on localhost at port 9999
	var err = _client.connect_to_host("127.0.0.1", 9999)

	if err == OK:
		print("Connected to server!")
		return true
	else:
		push_error("Failed to connect: ", err)
		return false

func _launch_python_ai_server():
	var python_script = "../ai-server/ai_server.py"
	var output = []
	# Run the Python script
	var _result = OS.execute("cmd", ["/c", "start", "python3", python_script, "&&", "pause"], output, true, true)

func _send_json(data: Dictionary):
	_client.poll()
	var json_string = JSON.stringify(data)
	var utf8_buffer = json_string.to_utf8_buffer()

	## Wrap StreamPeerTCP with StreamPeerGZIP
	#var gzip = StreamPeerGZIP.new()
	#var chunk_size = 1024 # 1 MB chunks
	#var data_length = utf8_buffer.size()
	#var offset = 0
#
	#gzip.start_compression(false, data_length * chunk_size)
	#while offset < data_length:
		#var end = min(offset + chunk_size, data_length)
		#var chunk = utf8_buffer.slice(offset, end)
#
		#var put_error = gzip.put_data(chunk)
		#if put_error != OK:
			#print("Error while compressing chunk:", put_error)
			#break
		#offset = end
#
	#var error = gzip.finish()
	#if error:
		#pass
	#var compressed_data = gzip.get_data(gzip.get_available_bytes())[1]
	#var compressed_data_size = compressed_data.size()
#
	#_client.put_data(compressed_data)
	_client.put_data(utf8_buffer)

func _receive_json() -> Dictionary:
	var response_buffer = ""
	var response: Dictionary
	while !response:
		if _client.get_available_bytes() > 0:
			var received_string = _client.get_utf8_string(_client.get_available_bytes())
			response_buffer += received_string
			var json = JSON.new()
			var error = json.parse(response_buffer)
			if error == OK:
				response = json.data
				if typeof(response) == TYPE_DICTIONARY:
					pass
				else:
					print("Unexpected data")
			else:
				pass
		else:
			return response

	return response

func get_action(state: Array[float]) -> Array[float]:
	while _is_communicating:
		await get_tree().create_timer(0.05).timeout

	_is_communicating = true

	var data = {}
	data[AICommands.new().command] = AICommands.new().get_action

	var snapped_state = []
	for val in state:
		snapped_state.append(snapped(val, rounding_precision))
	data["state"] = snapped_state

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.01).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false

	var action: Array[float] = []

	var action_response = response["action"]
	if action_response is Array:
		for val in action_response:
			action.append(val)
	else:
		action.append(action_response)

	return action

# input  : [state0, state1, ..., stateN]
# returns: [action0, action1, ..., actionN]
func get_batch_actions(states_2d_array: Array, deterministic: bool) -> Array:
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true

	var batch_state_path = "AIServerCommFiles/batch_state.json"
	var data = {}
	data[AICommands.new().command] = AICommands.new().get_batch_actions
	data["deterministic"] = deterministic
	data["path"] = batch_state_path

	var batch = []
	for state in states_2d_array:
		for s in state:
			batch.append(snapped(s, rounding_precision))

	var batch_state_dict = {}
	batch_state_dict["batch_state"] = batch
	_save_dict_to_json(batch_state_path, batch_state_dict)

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false

	var actions_path = response["path"]
	var batch_actions_dict = _get_dict_from_json(actions_path)
	var batch_actions: Array[float] = []
	for f in batch_actions_dict["actions"]:
		batch_actions.append(f)

	var action_size = batch_actions.size() / states_2d_array.size()
	var actions: Array = []
	for i in range(batch_actions.size()):
		if i % action_size == 0:
			var arr: Array[float] = []
			actions.append(arr)
		actions[actions.size() - 1].append(batch_actions[i])

	return actions

func submit_batch_replay(replays: Array[Replay]):
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true
	var action: Array[float] = []

	var batch_replays_path = "AIServerCommFiles/batch_replays.json"
	var data = {}
	data[AICommands.new().command] = AICommands.new().submit_batch_replay
	data["path"] = batch_replays_path

	var replay_data = []
	for replay in replays:
		replay_data.append(replay.to_data())

	var replay_dictionary = {}
	replay_dictionary["replays"] = replay_data
	_save_dict_to_json(batch_replays_path, replay_dictionary)

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false
	return action

func train(steps: int, make_checkpoint: bool, print_logs: bool):
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true
	var action: Array[float] = []

	var data = {}
	data[AICommands.new().command] = AICommands.new().train

	data["print_logs"] = print_logs
	data["steps"] = steps

	if make_checkpoint:
		data["checkpoint"] = 1

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false
	return action

func init_agent(state_dim: int, action_dim: int, batchsize: int, hidden_size: int, num_actor_layers: int, num_critic_layers: int):
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true
	var action: Array[float] = []

	var data = {}
	data[AICommands.new().command] = AICommands.new().init_agent

	data["state_dim"] = state_dim
	data["action_dim"] = action_dim
	data["batchsize"] = batchsize
	data["hidden_size"] = hidden_size
	data["num_actor_layers"] = num_actor_layers
	data["num_critic_layers"] = num_critic_layers

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false
	return action

func load_agent(step_count: int):
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true

	var data = {}
	data[AICommands.new().command] = AICommands.new().load_agent

	data["step_count"] = step_count

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false
	return response

func write_policy():
	while _is_communicating:
		await get_tree().create_timer(1).timeout

	_is_communicating = true
	var action: Array[float] = []

	var data = {}
	data[AICommands.new().command] = AICommands.new().write_policy

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false
	return action

func _save_dict_to_json(file_path: String, data: Dictionary) -> bool:
	# Open the file for writing
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# Convert the dictionary to a JSON string
		var json_string = JSON.stringify(data)
		# Write the JSON string to the file
		file.store_string(json_string)
		file.close()
		return true
	else:
		return false

func _get_dict_from_json(file_path: String) -> Dictionary:
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)

		if error == OK:
			var json_data = json.data
			if typeof(json_data) == TYPE_DICTIONARY:
				return json_data
			else:
				push_error("Unexpected data when parsing json")
	else:
		push_error("JSON File does not exist: ", file_path)

	return {}

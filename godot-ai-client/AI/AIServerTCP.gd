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

func get_action(state: Array[float], file_name: String) -> Array[float]:
	while _is_communicating:
		await get_tree().create_timer(0.05).timeout

	_is_communicating = true

	var data = {}
	data[AICommands.new().command] = AICommands.new().get_action

	var snapped_state = []
	for val in state:
		snapped_state.append(snapped(val, rounding_precision))
	data["state"] = snapped_state
	data["file_name"] = file_name

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

func get_batch_actions(agent_to_states_map: Dictionary, deterministic_map: Dictionary) -> Dictionary:
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true

	var batch_state_path = "AIServerCommFiles/batch_state.json"
	var data = {}
	data[AICommands.new().command] = AICommands.new().get_batch_actions
	data["deterministic_map"] = deterministic_map
	data["path"] = batch_state_path

	var agent_to_consumable_batch_states = {}
	for agent_name in agent_to_states_map.keys():
		var states_2d_array: Array = agent_to_states_map[agent_name]
		var batch = []
		for state in states_2d_array:
			for s in state:
				batch.append(snapped(s, rounding_precision))
		agent_to_consumable_batch_states[agent_name] = batch

	var batch_state_dict = {}
	batch_state_dict["batch_state"] = agent_to_consumable_batch_states
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
	var batch_actions_map = {}

	for agent_name in batch_actions_dict.keys():
		var batch_actions: Array[float] = []
		for float_value in batch_actions_dict[agent_name]:
			batch_actions.append(float_value)

		var action_size = batch_actions.size() / agent_to_states_map[agent_name].size()
		var actions: Array = []
		for i in range(batch_actions.size()):
			if i % action_size == 0:
				var arr: Array[float] = []
				actions.append(arr)
			actions[actions.size() - 1].append(batch_actions[i])
		batch_actions_map[agent_name] = actions

	return batch_actions_map

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
		var d = replay.to_data()
		if d.has("agent_name"):
			replay_data.append(d)
		else:
			push_error("Expected replay to have corresponding agent's name.")

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

func train(steps: int, file_name: String, print_logs: bool):
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true
	var action: Array[float] = []

	var data = {}
	data[AICommands.new().command] = AICommands.new().train

	data["print_logs"] = print_logs
	data["steps"] = steps

	data["file_name"] = file_name

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false
	return action

func init_agent(file_name: String, state_dim: int, action_dim: int, batchsize: int, hidden_size: int, num_actor_layers: int, num_critic_layers: int):
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true
	var action: Array[float] = []

	var data = {}
	data[AICommands.new().command] = AICommands.new().init_agent

	data["file_name"] = file_name
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

func load_agent(file_name: String):
	while _is_communicating:
		await get_tree().create_timer(2).timeout

	_is_communicating = true

	var data = {}
	data[AICommands.new().command] = AICommands.new().load_agent

	data["file_name"] = file_name

	_send_json(data)

	var response: Dictionary
	while !response:
		await get_tree().create_timer(0.1).timeout
		_client.poll()
		response = _receive_json()

	_is_communicating = false
	return response

func write_policy(file_name: String):
	while _is_communicating:
		await get_tree().create_timer(1).timeout

	_is_communicating = true
	var action: Array[float] = []

	var data = {}
	data[AICommands.new().command] = AICommands.new().write_policy
	data["file_name"] = file_name

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

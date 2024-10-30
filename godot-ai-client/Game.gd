extends Node2D

class_name Game

@export var infantry_unit_ui: PackedScene
@export var camera: Camera2D
@export var training_details_label: Label

@export var _ai_server: AIServerTCP

var _train_epoch = 0

var _battle_simulation = BattleSimulation.new()

var _combat_unit_uuids_to_ui = {}

var _current_selected_combat_unit: CombatUnitNode
var _loop_train = false

# Called when the node enters the scene tree for the first time.
func _ready():
	_setup_new_random_simulation()

func _input(event):
	var keyboard_event = event as InputEventKey
	var mouse_button_event = event as InputEventMouseButton
	if keyboard_event and keyboard_event.is_released():
		match keyboard_event.keycode:
			KEY_R:
				_setup_new_random_simulation()
			KEY_SPACE:
				_battle_simulation.commit_moves()
				_refresh_combat_ui()
			KEY_1: # get move
				_agent_make_move()
			KEY_2: # get moves and submit batch or replay
				_generate_and_submit_batch_replay(500)
			KEY_3:
				_train_agent(0) # force special case
			KEY_4:
				if _loop_train:
					return
				_train_epoch = 0
				_loop_train = true
				_train_and_demonstrate()
			KEY_T:
				_test_agent()
			KEY_0:
				_loop_train = false


	if mouse_button_event and mouse_button_event.is_pressed() and _current_selected_combat_unit:
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			_battle_simulation.stage_move(_current_selected_combat_unit._uuid, get_global_mouse_position())
		if mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
			var target_rotation = _current_selected_combat_unit.get_rotation_to(get_global_mouse_position())
			_battle_simulation.stage_rotate(_current_selected_combat_unit._uuid, target_rotation)


func did_select_combat_unit_ui(combat_unit_ui: CombatUnitUI):
	await get_tree().process_frame

	if _current_selected_combat_unit and _current_selected_combat_unit == combat_unit_ui:
		_current_selected_combat_unit = null
		return

	_current_selected_combat_unit = _battle_simulation.get_combat_unit(combat_unit_ui._combat_unit_node_uuid)

func update_training_stats(epochs: int, seconds_elapsed: int):
	training_details_label.text = "epochs: " + str(epochs) + ", seconds: " + str(seconds_elapsed)

func _refresh_combat_ui():
	for k in _combat_unit_uuids_to_ui.keys():
		var ui: CombatUnitUI = _combat_unit_uuids_to_ui[k]
		ui.refresh()

func _add_ui(unit: CombatUnitNode):
	var unit_ui = infantry_unit_ui.instantiate() as CombatUnitUI

	unit_ui.set_node(unit, _battle_simulation)
	unit_ui.game_delegate = self

	_combat_unit_uuids_to_ui[unit_ui._combat_unit_node_uuid] = unit_ui
	add_child(unit_ui)

func _setup_new_random_simulation():
	_battle_simulation = random_new_battle()
	_add_ui_for_simulation(_battle_simulation)

func random_new_battle() -> BattleSimulation:
	var new_battle_simulation = BattleSimulation.new()

	var blue_1 = CombatUnitNode.new(
		CombatUnitNode.Army.blue,
		CombatUnitNode.Unit.infantry,
		new_battle_simulation
	)
	blue_1._uuid = 0
	new_battle_simulation.add_combat_unit(blue_1)

	var red_1 = CombatUnitNode.new(
		CombatUnitNode.Army.red,
		CombatUnitNode.Unit.infantry,
		new_battle_simulation
	)
	red_1._uuid = 1
	new_battle_simulation.add_combat_unit(red_1)

	var battle_size = 500
	blue_1.position = Vector2(randf_range(-battle_size, battle_size), randf_range(-battle_size, battle_size))
	red_1.position = Vector2(randf_range(-battle_size, battle_size), randf_range(-battle_size, battle_size))
	red_1.rotation = -PI

	return new_battle_simulation


func _add_ui_for_simulation(simulation: BattleSimulation):
	for key in _combat_unit_uuids_to_ui.keys():
		_combat_unit_uuids_to_ui[key].queue_free()

	_combat_unit_uuids_to_ui = {}
	_current_selected_combat_unit = null

	for k in simulation._combat_unit_uuids_to_units.keys():
		var unit: CombatUnitNode = simulation._combat_unit_uuids_to_units[k]
		_add_ui(unit)

	_refresh_combat_ui()

func agent_did_commit_move():
	_refresh_combat_ui()

func _agent_make_move() -> bool:
	var red_unit = _battle_simulation.get_army(CombatUnitNode.Army.red)[0]
	var input_vector = _battle_simulation.get_battle_input_vector_for_unit(red_unit)
	var action = await _ai_server.get_action(input_vector)
	_battle_simulation.stage_move_using_direction_and_magnitude(red_unit._uuid, action[0], action[1] * red_unit.movement_range)
	_battle_simulation.commit_moves()
	_refresh_combat_ui()
	return true

func _generate_and_submit_batch_replay(batch_size: int) -> bool:
	var red_unit = _battle_simulation.get_army(CombatUnitNode.Army.red)[0]
	var battles: Array[BattleSimulation] = []
	var batch_inputs = []

	# Setup battles
	for i in range(batch_size):
		var battle = random_new_battle()
		battles.append(battle)

	for step in range(3):
		batch_inputs.clear()
		for battle in battles:
			batch_inputs.append(battle.get_battle_input_vector_for_unit(red_unit))
		var replays: Array[Replay] = await _batch_step_battles(battles, false)
		var total_reward: float = 0
		for replay in replays:
			total_reward += replay.reward

		print("average batch reward: " + str(total_reward / float(replays.size())))

		var response = await _ai_server.submit_batch_replay(replays)

	return true

func _train_agent(current_epoch: int) -> bool:
	var should_print_logs = false
	var should_make_checkpoint = false
	if current_epoch % 5 == 0:
		should_make_checkpoint = true
	var response = await _ai_server.train(10, should_make_checkpoint, true)
	return true

func _train_and_demonstrate() -> bool:
	if !_loop_train:
		return false

	print()
	print("----------")
	print("epoch: " + str(_train_epoch))
	if Input.is_key_pressed(KEY_ENTER):
		await _test_agent()

		_setup_new_random_simulation()
		await get_tree().create_timer(0.35).timeout
		for i in range(3):
			await get_tree().create_timer(0.35).timeout
			await _agent_make_move()

	_train_epoch += 1
	await _generate_and_submit_batch_replay(50)
	await _train_agent(_train_epoch)

	await _train_and_demonstrate()
	return true

func _test_agent():
	var battles: Array[BattleSimulation] = []

	var positions: Array[Vector2] = [
		Vector2(-500, -500),
		Vector2(0, -500),
		Vector2(500, -500),

		Vector2(-500, 0),
		Vector2(500, -0),

		Vector2(-500, 500),
		Vector2(0, 500),
		Vector2(-500, 500),
	]

	var evaluator = BattleEvaluator.new()
	# Setup battles
	for pos in positions:
		var battle = random_new_battle()
		var blue_unit = battle.get_army(CombatUnitNode.Army.blue)[0]
		var red_unit = battle.get_army(CombatUnitNode.Army.red)[0]
		blue_unit.position = Vector2.ZERO
		red_unit.position = pos
		battles.append(battle)

	var replays = await _batch_step_battles(battles, true)
	replays = await _batch_step_battles(battles, true)

	var total_reward = 0
	for battle in battles:
		var red_unit = battle.get_army(CombatUnitNode.Army.red)[0]
		total_reward += evaluator.evaluate(battle, red_unit._army)

	print("Averaged test reward: " + str( float(total_reward) / float(battles.size()) ))

func _batch_step_battles(battles: Array[BattleSimulation], deterministic: bool) -> Array[Replay]:
	var batch_inputs = []
	var replays: Array[Replay] = []

	# Get states to send to agent
	for battle in battles:
		var red_unit = battle.get_army(CombatUnitNode.Army.red)[0]
		batch_inputs.append(battle.get_battle_input_vector_for_unit(red_unit))

	# Get action from agent
	var actions = await _ai_server.get_batch_actions(batch_inputs, deterministic)

	# Apply action from agent
	var evaluator = BattleEvaluator.new()
	for i in range(battles.size()):
		var battle = battles[i]
		var red_unit = battle.get_army(CombatUnitNode.Army.red)[0]
		var state = battles[i].get_battle_input_vector_for_unit(red_unit)
		var action = actions[i]
		battles[i].stage_move_using_direction_and_magnitude(red_unit._uuid, action[0], action[1] * red_unit.movement_range)
		battles[i].commit_moves()
		var state_ = battles[i].get_battle_input_vector_for_unit(red_unit)
		var reward = evaluator.evaluate(battles[i], red_unit._army)
		var done = 0
		if reward >= 0:
			done = 1
		var replay = Replay.new(state, action, reward, state_, done)
		replays.append(replay)

	return replays

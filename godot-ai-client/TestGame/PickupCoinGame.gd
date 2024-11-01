extends Node2D

@export var hero: Node2D
@export var coin: Node2D
@export var _ai_tcp: AIServerTCP

var _map_size = Vector2(1500, 800)

var move_speed = 500

var _is_loop_training = false
var _is_testing = false

# Called when the node enters the scene tree for the first time.
func _ready():
	_new_game()

func _input(event):
	var key_input = event as InputEventKey
	if !key_input:
		return

	if key_input.echo or key_input.is_released():
		return
	match key_input.keycode:
		KEY_ENTER:
			if _is_loop_training or _is_testing:
				return
			_is_testing = true
			var result = await _get_batch_from_playing_round(true)
			_is_testing = false

		KEY_N:
			_new_game()
		KEY_UP:
			_setup_ai()
		KEY_1: # Get and Apply action
			var current_state = _get_game_state()
			var start_time = Time.get_ticks_msec()
			var action = await _ai_tcp.get_action(current_state)
			var _time_elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
			_move_hero(_time_elapsed, action[0])
		KEY_2: # Get and Submit batch
			var replays = await _get_batch_from_playing_round(false)
			var response = await _ai_tcp.submit_batch_replay(replays)
		KEY_3: # Start training loop
			_loop_train()

func _physics_process(delta):
	var apply_move = false
	var move_vector: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		apply_move = true
		move_vector += Vector2.UP
	if Input.is_key_pressed(KEY_A):
		apply_move = true
		move_vector += Vector2.LEFT
	if Input.is_key_pressed(KEY_S):
		apply_move = true
		move_vector += Vector2.DOWN
	if Input.is_key_pressed(KEY_D):
		apply_move = true
		move_vector += Vector2.RIGHT

	if apply_move:
		_move_hero(delta, move_vector.angle())
		if _is_game_complete():
			_new_game()
			return

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return
	result = await _ai_tcp.init_agent(4, 1, 20, 40)
	_ai_tcp.load_agent(1)

func _new_game():
	hero.position = Vector2(randf_range(-_map_size.x/2, _map_size.x/2), randf_range(-_map_size.y/2, _map_size.y/2))
	coin.position = Vector2(randf_range(-_map_size.x/2, _map_size.x/2), randf_range(-_map_size.y/2, _map_size.y/2))
	if _is_game_complete():
		_new_game()

func _is_game_complete() -> bool:
	return hero.position.distance_to(coin.position) < 80

func _move_hero(delta_time: float, direction: float):
	var move_vector = Vector2.from_angle(direction)
	hero.position += move_vector * move_speed * delta_time

func _get_game_state() -> Array[float]:
	return [hero.position.x, hero.position.y, coin.position.x, coin.position.y]


func _get_batch_from_playing_round(deterministic: bool) -> Array[Replay]:
	_new_game()
	var batch: Array[Replay] = []
	var start_time = Time.get_ticks_msec()
	var average_reward = 0

	while Time.get_ticks_msec() - start_time < 1000.0:
		var score_before = _get_score()
		var t = Time.get_ticks_msec()
		var state = _get_game_state()
		var actions = await _ai_tcp.get_batch_actions([state], deterministic)
		var action = actions[0] # Since we are not simulating in parallel, there is only 1 action
		var _time_elapsed = (Time.get_ticks_msec() - t) / 1000.0
		_move_hero(_time_elapsed, action[0])
		var state_ = _get_game_state()
		var is_done = _is_game_complete()
		var score_after = _get_score()
		var reward = score_after - score_before
		if reward > 0:
			reward = 100
		else:
			reward = -100
		var replay = Replay.new(state, action, reward, state_, is_done)
		batch.append(replay)
		average_reward = score_after - score_before

		if is_done:
			break

	average_reward /= float(batch.size())
	if deterministic:
		print("Average Reward: " + str(average_reward))

	return batch

func _get_score() -> float:
	return 1000.0 - hero.position.distance_to(coin.position)

func _loop_train():
	if _is_loop_training:
		return

	_is_loop_training = true
	var replays = await _get_batch_from_playing_round(false)
	var response = await _ai_tcp.submit_batch_replay(replays)
	response = await _ai_tcp.train(10, true, true)

	_is_loop_training = false
	if Input.is_key_pressed(KEY_ENTER):
		return
	else:
		_loop_train()

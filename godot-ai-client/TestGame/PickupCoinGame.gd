extends Node2D

@export var hero: Node2D
@export var coin: Node2D
@export var _ai_tcp: AIServerTCP

var _map_size = Vector2(1500, 800)

var move_speed = 500

# Called when the node enters the scene tree for the first time.
func _ready():
	_new_game()

func _input(event):
	var key_input = event as InputEventKey
	if !key_input or key_input.echo or key_input.is_released():
		return
	match key_input.keycode:
		KEY_N:
			_new_game()
		KEY_UP:
			_setup_ai()
		KEY_1: # Get and Apply action
			var current_state = _get_game_state()
			var start_time = Time.get_ticks_msec()
			var action = await _ai_tcp.get_action(current_state)
			var _time_elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
			_move_hero(1, action[0])
		KEY_2: # Get and Submit batch
			pass
		KEY_3: # Start training loop
			pass

func _physics_process(delta):
	if _is_game_complete():
		_new_game()
		return

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

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return
	_ai_tcp.init_agent(4, 1, 20, 40)

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

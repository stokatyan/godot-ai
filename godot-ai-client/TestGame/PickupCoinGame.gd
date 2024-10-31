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
			pass
		KEY_2: # Get and Submit batch
			pass
		KEY_3: # Start training loop
			pass

func _physics_process(delta):
	if _is_game_complete():
		_new_game()
		return

	var move_strength: float = 0
	var move_vector: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		move_strength = 1
		move_vector += Vector2.UP
	if Input.is_key_pressed(KEY_A):
		move_strength = 1
		move_vector += Vector2.LEFT
	if Input.is_key_pressed(KEY_S):
		move_strength = 1
		move_vector += Vector2.DOWN
	if Input.is_key_pressed(KEY_D):
		move_strength = 1
		move_vector += Vector2.RIGHT

	move_hero(move_strength * move_speed * delta, move_vector.angle())

func _setup_ai():
	var result = _ai_tcp.attempt_connection_to_ai_server()
	if !result:
		return
	_ai_tcp.init_agent(4, 2, 20, 40)

func _new_game():
	hero.position = Vector2(randf_range(-_map_size.x/2, _map_size.x/2), randf_range(-_map_size.y/2, _map_size.y/2))
	coin.position = Vector2(randf_range(-_map_size.x/2, _map_size.x/2), randf_range(-_map_size.y/2, _map_size.y/2))
	if _is_game_complete():
		_new_game()

func _is_game_complete() -> bool:
	return hero.position.distance_to(coin.position) < 80

func move_hero(force: float, direction: float):
	var move_vector = Vector2.from_angle(direction)
	move_vector *= force
	hero.position += move_vector

extends RefCounted

class_name PCGSimulation

var hero_position: Vector2
var coin_position: Vector2

var _map_size = Vector2(1500.0, 800.0)

func new_game():
	hero_position = Vector2(randf_range(-_map_size.x/2, _map_size.x/2), randf_range(-_map_size.y/2, _map_size.y/2))
	coin_position = Vector2(randf_range(-_map_size.x/2, _map_size.x/2), randf_range(-_map_size.y/2, _map_size.y/2))
	if is_game_complete():
		new_game()

func is_game_complete() -> bool:
	return hero_position.distance_to(coin_position) < 80

func move_hero(force: float, direction: float, callback = null):
	var move_vector = Vector2.from_angle(direction)
	hero_position += move_vector * force * 20
	if callback:
		callback.call(self)

func get_game_state() -> Array[float]:
	var x_r = _map_size.x/2
	var y_r = _map_size.y/2
	return [hero_position.x/x_r, hero_position.y/y_r, coin_position.x/x_r, coin_position.y/y_r]

func get_score() -> float:
	return 1.0 - hero_position.distance_to(coin_position)

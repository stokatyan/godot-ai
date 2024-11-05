extends FCGBaseNode

class_name FCGHero

var max_vision_distance: float:
	get:
		return 1000

func _init():
	_radius = 20

func move(direction: float, magnitude: float):
	_rotation = direction
	_position += Vector2.from_angle(direction) * magnitude * (_radius * 2)

func get_vision_angles() -> Array[float]:
	var _angles: Array[float] = [
		(0 + _rotation),

		(PI * 0.125 + _rotation),
		(PI * -0.125 + _rotation),

		(PI * 0.25 + _rotation),
		(PI * -0.25 + _rotation),

		(PI * 0.45 + _rotation),
		(PI * -0.45 + _rotation),
	]
	return _angles

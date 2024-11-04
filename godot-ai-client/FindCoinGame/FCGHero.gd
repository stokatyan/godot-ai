extends FCGBaseNode

class_name FCGHero

var max_vision_distance: float:
	get:
		return 100

func _init():
	_radius = 20

func move(direction: float, magnitude: float):
	_rotation = direction
	_position += Vector2.from_angle(direction) * magnitude * _radius

func get_vision_angles() -> Array[float]:
	var _angles: Array[float] = [
		(0 + _rotation),
		(PI * 0.25 + _rotation),
		(PI * 0.5 + _rotation),
		(PI * -0.25 + _rotation),
		(PI * -0.5 + _rotation),
	]
	return _angles

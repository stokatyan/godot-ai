extends FCGBaseNode

class_name FCGHero

var _physics_body: RID
var _physics_shape: RID

var rotation: float = 0
var position: Vector2 = Vector2.ZERO

var max_vision_distance: float:
	get:
		return 1000

func _init():
	_radius = 20
	_physics_body = PhysicsServer2D.body_create()
	_physics_shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(_physics_shape, _radius)
	PhysicsServer2D.body_add_shape(_physics_body, _physics_shape)
	PhysicsServer2D.body_set_mode(_physics_body, PhysicsServer2D.BodyMode.BODY_MODE_KINEMATIC)


func get_vision_angles() -> Array[float]:
	var _angles: Array[float] = [
		(0 + rotation),

		(PI * 0.1 + rotation),
		(PI * -0.1 + rotation),

		(PI * 0.21 + rotation),
		(PI * -0.21 + rotation),

		(PI * 0.33 + rotation),
		(PI * -0.33 + rotation),

		(PI * 0.45 + rotation),
		(PI * -0.45 + rotation),
	]
	return _angles

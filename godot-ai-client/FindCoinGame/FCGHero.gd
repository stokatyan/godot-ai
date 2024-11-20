extends FCGBaseNode

class_name FCGHero

var _physics_body: RID
var _physics_shape: RID

var _rotation: float:
	get:
		return PhysicsServer2D.body_get_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM).get_rotation()

var _position: Vector2:
	get:
		return PhysicsServer2D.body_get_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM).origin

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

func set_transform(position: Vector2, rotation: float):
	var new_transform = Transform2D(rotation, position)
	PhysicsServer2D.body_set_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)

func get_vision_angles() -> Array[float]:
	var _angles: Array[float] = [
		(0 + _rotation),

		(PI * 0.1 + _rotation),
		(PI * -0.1 + _rotation),

		(PI * 0.21 + _rotation),
		(PI * -0.21 + _rotation),

		(PI * 0.33 + _rotation),
		(PI * -0.33 + _rotation),

		(PI * 0.45 + _rotation),
		(PI * -0.45 + _rotation),
	]
	return _angles

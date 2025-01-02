extends RefCounted

class_name BRBaseNode

var _physics_body: RID
var _physics_shape: RID
var _radius: float = 0
var _is_freed = false

var _rotation: float:
	get:
		return _transform.get_rotation()

var _position: Vector2:
	get:
		return _transform.origin

var _transform: Transform2D:
	get:
		return PhysicsServer2D.body_get_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM)

func set_transform(position: Vector2, rotation: float):
	var new_transform = Transform2D(rotation, position)
	PhysicsServer2D.body_set_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)

func free_from_physics_server():
	if _is_freed:
		return
	_is_freed = true
	PhysicsServer2D.free_rid(_physics_shape)
	PhysicsServer2D.free_rid(_physics_body)

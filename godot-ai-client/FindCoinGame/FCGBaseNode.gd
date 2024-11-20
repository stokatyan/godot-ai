extends RefCounted

class_name FCGBaseNode

var _physics_body: RID
var _physics_shape: RID
var _radius: float = 0

var _rotation: float:
	get:
		return PhysicsServer2D.body_get_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM).get_rotation()

var _position: Vector2:
	get:
		return PhysicsServer2D.body_get_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM).origin

func set_transform(position: Vector2, rotation: float):
	var new_transform = Transform2D(rotation, position)
	PhysicsServer2D.body_set_state(_physics_body, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)

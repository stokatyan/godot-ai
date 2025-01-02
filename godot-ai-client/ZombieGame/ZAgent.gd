extends BRBaseNode

class_name ZAgent

var _health: float = 1.0
var _attack_damage: float = 0.15

var max_vision_distance: float =  700

var is_dead: bool:
	get:
		return _health <= 0

func _init():
	_radius = 20
	_physics_body = PhysicsServer2D.body_create()
	_physics_shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(_physics_shape, _radius)
	PhysicsServer2D.body_add_shape(_physics_body, _physics_shape)
	PhysicsServer2D.body_set_mode(_physics_body, PhysicsServer2D.BodyMode.BODY_MODE_KINEMATIC)

func get_vision_angles() -> Array[float]:
	var r: float = _rotation
	var _angles: Array[float] = []
	assert(false, "get_vision_angles not implemented")
	return _angles

func did_get_hit(damage_taken: float):
	_health -= damage_taken
	_health = max(0, _health)

	if _health == 0:
		free_from_physics_server()

## Get all agent stats converted from 0->1 to -1->1
func get_stats() -> Array[float]:
	var stats: Array[float] = []
	assert(false, "get_stats not implemented")
	return stats

func _double_and_subtract_one(val: ) -> float:
	return val * 2 - 1.0

func step_did_elapse(steps: float = 1.0):
	assert(false, "step_did_elapse not implemented")

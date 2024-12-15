extends BRBaseNode

class_name BRAgent

var _health: float = 1.0
var _attack_damage: float = 0.25

var _current_ammo: float = 0.20
var _ammo_per_reload: float = 0.20
var _ammo_cost_per_shot: float:
	get:
		return 0.01

var _reload_delay_remaining = 0.0
var _reload_speed = 0.1
var _reload_time_per_frame: float:
	get:
		return 0.01

var _fire_rate = 0.5
var _fire_delay_remaining = 0.0
var _fire_time_per_frame: float:
	get:
		return 0.01

var max_vision_distance: float:
	get:
		return 700

func _init():
	_radius = 20
	_physics_body = PhysicsServer2D.body_create()
	_physics_shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(_physics_shape, _radius)
	PhysicsServer2D.body_add_shape(_physics_body, _physics_shape)
	PhysicsServer2D.body_set_mode(_physics_body, PhysicsServer2D.BodyMode.BODY_MODE_KINEMATIC)

func get_vision_angles() -> Array[float]:
	var r: float = _rotation
	var _angles: Array[float] = [
		(0 + r),

		(PI * 0.1 + r),
		(PI * -0.1 + r),

		(PI * 0.21 + r),
		(PI * -0.21 + r),

		(PI * 0.33 + r),
		(PI * -0.33 + r),

		(PI * 0.48 + r),
		(PI * -0.48 + r),

		(PI * 0.60 + r),
		(PI * -0.60 + r),
		(PI * 0.75 + r),
		(PI * -0.75 + r),
	]
	return _angles

func did_get_hit(damage_taken: float):
	_health -= damage_taken
	_health = max(0, _health)

## Get all agent stats converted from 0->1 to -1->1
func get_stats() -> Array[float]:
	var stats: Array[float] = [
		_health * 2.0 - 1.0,
		_attack_damage * 2.0 - 1.0,
		_current_ammo * 2.0 - 1.0,
		_ammo_per_reload * 2.0 - 1.0,
		_reload_delay_remaining * 2.0 - 1.0,
		_reload_speed * 2.0 - 1.0,
	]

	return stats

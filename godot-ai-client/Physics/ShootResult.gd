extends RefCounted

class_name ShootResult

var hit_point: Vector2
var hit_body: RID

func _init(hit_point: Vector2, hit_body: RID):
	self.hit_point = hit_point
	self.hit_body = hit_body

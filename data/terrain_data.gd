@tool
extends Updatable

class_name TerrainData

@export var uniform_scale: float = 2.5
@export var use_falloff: bool = false
@export var use_flat_shading: bool = false

@export var min_height: float:
	get:
		return uniform_scale * height_multiplier * mesh_height_curve.sample(0)
		
@export var max_height: float:
	get:
		return uniform_scale * height_multiplier * mesh_height_curve.sample(1)

@export_range(1, 50) var height_multiplier: float:
	get:
		return height_multiplier
	set(value):
		height_multiplier = value
		if (auto_update):
			print('OH !')
			emit_changed()
		
@export var mesh_height_curve: Curve:
	get:
		return mesh_height_curve
	set(value):
		mesh_height_curve = value
		if (auto_update):
			emit_changed()
		
func _init(_uniform_scale: float = 2.5, _use_flat_shading: bool = false, _use_falloff: bool = false, _height_multiplier: float = 1, _mesh_height_curve: Curve = Curve.new()):
	uniform_scale = _uniform_scale
	use_flat_shading = _use_flat_shading
	use_falloff = _use_falloff
	height_multiplier = _height_multiplier
	mesh_height_curve = _mesh_height_curve

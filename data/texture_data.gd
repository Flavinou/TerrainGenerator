@tool
extends Updatable

class_name TextureData

func update_mesh_heights(_material: ShaderMaterial, _min_height: float, _max_height: float) -> void:
	_material.set_shader_parameter("min_height", _min_height)
	_material.set_shader_parameter("max_height", _max_height)

func apply_to_material(_material: ShaderMaterial) -> void:
	return

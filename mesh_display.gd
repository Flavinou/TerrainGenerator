@tool
extends MeshInstance3D

class_name MeshDisplay

func draw_mesh(_mesh_data: MeshData, _texture: ImageTexture) -> void:
	mesh = _mesh_data.create_mesh()
	
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = _texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	set_surface_override_material(0, material)

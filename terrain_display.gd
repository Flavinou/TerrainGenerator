@tool
extends MeshInstance3D

class_name TerrainDisplay

func draw_texture(_texture: ImageTexture) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = _texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	set_surface_override_material(0, material)
	scale = Vector3(_texture.get_width(), 1, _texture.get_height())

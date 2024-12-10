@tool
extends MeshInstance3D

class_name MeshDisplay

@export var terrain_generator: TerrainGenerator

#@onready var terrain_generator: TerrainGenerator = get_node("/root/TerrainGenerator")

func draw_mesh(_mesh_data: MeshData) -> void:
	if terrain_generator == null:
		return
	
	mesh = _mesh_data.create_mesh()
	scale = Vector3.ONE * terrain_generator.terrain_data.uniform_scale

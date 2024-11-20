extends Node3D

class_name TerrainChunk

@onready var terrain_generator = get_node("/root/TerrainGenerator")

@export var mesh_instance: MeshInstance3D
var size: int
var chunk_position: Vector2
var bounds: AABB

# Annoying dependency to viewer's position
var world_position: Vector3

func _ready():
	if not terrain_generator:
		push_warning('Could not find TerrainGenerator node, no further request will be made.')
		return
		
	mesh_instance.global_position = world_position
		
	terrain_generator.request_map_data(on_map_data_received)
	

func _init(_coordinates: Vector2, _size: int, _parent: Node, _material: Material):
	size = _size
	chunk_position = _coordinates * _size
	bounds = AABB(Vector3(chunk_position.x, 0, chunk_position.y), Vector3.ONE * _size)
	world_position = Vector3(chunk_position.x, 0, chunk_position.y)
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.material_override = _material
	add_child.call_deferred(mesh_instance)
	_parent.add_child.call_deferred(self)
	
	toggle_visible(false)
	
	
func on_map_data_received(_map_data: MapData) -> void:
	print("Map data received !")
	terrain_generator.request_mesh_data(_map_data, on_mesh_data_received)
	
	
func on_mesh_data_received(_mesh_data: MeshData) -> void:
	print("Mesh data received !")
	mesh_instance.mesh = _mesh_data.create_mesh()
	
	
func update(_viewer_position: Vector3):
	# Find the distance between the closest point on the terrain chunk bounding box and the viewer's position
	var closest_point: Vector3 = find_closest_point(bounds, _viewer_position)
	var viewer_distance_from_nearest_edge: float = _viewer_position.distance_to(closest_point)
	
	# The terrain chunk is visible only if its nearest point distance to the viewer is less than the specified threshold
	var should_be_visible: bool = viewer_distance_from_nearest_edge <= EndlessTerrain.MAX_VIEW_DST
	toggle_visible(should_be_visible)
	

func find_closest_point(_aabb: AABB, _point: Vector3) -> Vector3:
	var result: Vector3 = Vector3()
	
	var half: Vector3 = _aabb.size / 2
	var center: Vector3 = _aabb.get_center()
	
	var aabb_min: Vector3 = center - half
	var aabb_max: Vector3 = center + half
	
	return result.clamp(aabb_min, aabb_max)


func toggle_visible(_is_visible: bool) -> void:
	set_visible(_is_visible)
	mesh_instance.set_visible(_is_visible)

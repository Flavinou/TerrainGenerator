extends Node3D

class_name TerrainChunk

var mesh_instance: MeshInstance3D
var size: int
var chunk_position: Vector2
var bounds: AABB

# Annoying dependency to viewer's position
var world_position: Vector3

func _init(_coordinates: Vector2, _size: int):
	size = _size
	chunk_position = _coordinates * _size
	bounds = AABB(Vector3(chunk_position.x, 0, chunk_position.y), Vector3.ONE * _size)
	world_position = Vector3(chunk_position.x, 0, chunk_position.y)
	mesh_instance = MeshInstance3D.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	
	# Set to white texture at the moment
	material.albedo_color = Color(0.0, 0.0, 1.0, 1.0)
	
	mesh_instance.mesh = PlaneMesh.new()
	mesh_instance.position = world_position
	mesh_instance.scale = Vector3.ONE * size / 2.0
	mesh_instance.set_surface_override_material(0, material)
	
	toggle_visible(false)
	add_child(mesh_instance)
	
	
#func _ready():
	
	
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

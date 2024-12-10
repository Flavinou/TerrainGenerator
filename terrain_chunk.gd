extends Node3D

class_name TerrainChunk

@onready var terrain_generator = get_node("/root/TerrainGenerator")

var mesh_instance: MeshInstance3D
var physics_body: StaticBody3D
var collision_shape: CollisionShape3D
var size: int
var chunk_position: Vector2
var bounds: Rect2

# Annoying dependency to viewer's position
var world_position: Vector3

var detail_levels: Array[LODInfo] = []
var lod_meshes: Array[LODMesh] = []
var collision_lod_mesh: LODMesh

var map_data: MapData
var map_data_received: bool = false
var previous_lod_index: int = -1

# Using shared memory is a bit annoying, so passing it as reference to the constructor of this model
var viewer_position: Vector2
var max_view_distance: float

func _ready():
	if not terrain_generator:
		push_warning('Could not find TerrainGenerator node, no further request will be made.')
		return
		
	for i in range(detail_levels.size()):
		lod_meshes[i] = LODMesh.new(terrain_generator, detail_levels[i].lod, update.bind(viewer_position, max_view_distance))
		if detail_levels[i].use_for_collider:
			collision_lod_mesh = lod_meshes[i]
		
	mesh_instance.global_position = world_position * terrain_generator.terrain_data.uniform_scale
	mesh_instance.scale_object_local(Vector3.ONE * terrain_generator.terrain_data.uniform_scale)
		
	terrain_generator.request_map_data(chunk_position, on_map_data_received)
	

func _init(_coordinates: Vector2, _size: int, _detail_levels: Array[LODInfo], _parent: Node, _material: Material, _max_view_dst: float):
	size = _size
	chunk_position = _coordinates * _size
	bounds = Rect2(chunk_position, Vector2.ONE * size)
	world_position = Vector3(chunk_position.x, 0, chunk_position.y)
	max_view_distance = _max_view_dst
	detail_levels = _detail_levels
	lod_meshes.resize(detail_levels.size())
	
	mesh_instance = MeshInstance3D.new()
	physics_body = StaticBody3D.new()
	collision_shape = CollisionShape3D.new()
	mesh_instance.material_override = _material
	
	physics_body.add_child.call_deferred(collision_shape)
	mesh_instance.add_child.call_deferred(physics_body)
	
	add_child.call_deferred(mesh_instance)
	_parent.add_child.call_deferred(self)
	
	toggle_visible(false)
	
	
func _process(_delta):
	viewer_position = Shared.viewer_position
	
	
func on_map_data_received(_map_data: MapData) -> void:
	map_data = _map_data
	map_data_received = true
	
	update.call_deferred(viewer_position, max_view_distance)
	
	
func update(_viewer_position: Vector2, _max_view_distance: float):
	if not map_data_received:
		return
	
	# Find the distance between the closest point on the terrain chunk bounding box and the viewer's position
	var closest_point: Vector2 = find_closest_point(bounds, _viewer_position)
	var viewer_distance_from_nearest_edge: float = _viewer_position.distance_to(closest_point)
	
	# The terrain chunk is visible only if its nearest point distance to the viewer is less than the specified threshold
	var should_be_visible: bool = viewer_distance_from_nearest_edge <= _max_view_distance
	if (should_be_visible):
		var lod_index: int = 0
		for i in range(detail_levels.size() - 1):
			if viewer_distance_from_nearest_edge > detail_levels[i].visible_distance_threshold:
				lod_index = i + 1
			else:
				break
		
		if lod_index != previous_lod_index:
			var lod_mesh: LODMesh = lod_meshes[lod_index]
			if lod_mesh.has_mesh:
				previous_lod_index = lod_index
				mesh_instance.mesh = lod_mesh.mesh
			elif not lod_mesh.has_requested_mesh:
				lod_mesh.request_mesh(map_data)
				
		if lod_index == 0 and collision_lod_mesh.has_mesh:
			collision_shape.shape = collision_lod_mesh.mesh.create_trimesh_shape()
		elif not collision_lod_mesh.has_requested_mesh:
			collision_lod_mesh.request_mesh(map_data)
				
		Shared.last_visible_terrain_chunks.append(self)
	
	toggle_visible(should_be_visible)
	

func find_closest_point(_bounding_rect: Rect2, _point: Vector2) -> Vector2:
	var result: Vector2 = Vector2()
	
	var half: Vector2 = _bounding_rect.size / 2
	var center: Vector2 = _bounding_rect.get_center()
	
	var bounding_rect_min: Vector2 = center - half
	var bounding_rect_max: Vector2 = center + half
	
	return result.clamp(bounding_rect_min, bounding_rect_max)


func toggle_visible(_is_visible: bool) -> void:
	set_visible(_is_visible)
	mesh_instance.set_visible(_is_visible)

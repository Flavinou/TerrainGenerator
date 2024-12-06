extends RefCounted

class_name MeshData

var vertices: PackedVector3Array
var triangles: PackedInt32Array
var uvs: PackedVector2Array
var baked_normals: PackedVector3Array

var border_vertices: PackedVector3Array
var border_triangles: PackedInt32Array

var triangle_index: int
var border_triangle_index: int

func _init(_vertices_per_line: int):
	triangle_index = 0
	border_triangle_index = 0
	
	vertices = PackedVector3Array()
	vertices.resize(_vertices_per_line * _vertices_per_line)
	
	triangles = PackedInt32Array()
	triangles.resize((_vertices_per_line - 1) * (_vertices_per_line - 1) * 6)
	
	uvs = PackedVector2Array()
	uvs.resize(_vertices_per_line * _vertices_per_line)
	
	border_vertices = PackedVector3Array()
	border_vertices.resize(_vertices_per_line * 4 + 4)
	
	border_triangles = PackedInt32Array()
	border_triangles.resize(24 * _vertices_per_line)
	
	
func add_vertex(_vertex_position: Vector3, _uv: Vector2, _vertex_index: int):
	if _vertex_index < 0: # bordered mesh, do not add it to the final rendered mesh
		border_vertices[-_vertex_index - 1] = _vertex_position
	else:
		vertices[_vertex_index]	= _vertex_position
		uvs[_vertex_index] = _uv


func add_triangle(_a: int, _b: int, _c: int) -> void:
	if _a < 0 or _b < 0 or _c < 0: # bordered triangle
		border_triangles[border_triangle_index] = _a
		border_triangles[border_triangle_index + 1] = _b
		border_triangles[border_triangle_index + 2] = _c
		border_triangle_index += 3
	else:
		triangles[triangle_index] = _a
		triangles[triangle_index + 1] = _b
		triangles[triangle_index + 2] = _c
		triangle_index += 3


func create_mesh() -> ArrayMesh:
	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = triangles
	surface_array[Mesh.ARRAY_NORMAL] = baked_normals

	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return arr_mesh
	

func calculate_vertex_normals() -> PackedVector3Array:
	var vertex_normals = PackedVector3Array()
	vertex_normals.resize(vertices.size())
	
	var triangle_count: int = triangles.size() / 3
	for i in range(triangle_count):
		var normal_triangle_index: int = i * 3
		var vertex_index_a: int = triangles[normal_triangle_index]
		var vertex_index_b: int = triangles[normal_triangle_index + 1]
		var vertex_index_c: int = triangles[normal_triangle_index + 2]
		
		var triangle_normal: Vector3 = surface_normal_from_indices(vertex_index_a, vertex_index_b, vertex_index_c)
		vertex_normals[vertex_index_a] += triangle_normal
		vertex_normals[vertex_index_b] += triangle_normal
		vertex_normals[vertex_index_c] += triangle_normal
		
	var border_triangle_count: int = border_triangles.size() / 3
	for i in range(border_triangle_count):
		var normal_triangle_index: int = i * 3
		var vertex_index_a: int = border_triangles[normal_triangle_index]
		var vertex_index_b: int = border_triangles[normal_triangle_index + 1]
		var vertex_index_c: int = border_triangles[normal_triangle_index + 2]
		
		var triangle_normal: Vector3 = surface_normal_from_indices(vertex_index_a, vertex_index_b, vertex_index_c)
		if vertex_index_a >= 0:
			vertex_normals[vertex_index_a] += triangle_normal
		if vertex_index_b >= 0:
			vertex_normals[vertex_index_b] += triangle_normal
		if vertex_index_c >= 0:
			vertex_normals[vertex_index_c] += triangle_normal
		
	for i in range(vertex_normals.size()):
		vertex_normals[i] = vertex_normals[i].normalized()
	
	return vertex_normals
	
func surface_normal_from_indices(_ia: int, _ib: int, _ic: int) -> Vector3:
	var point_a: Vector3 = border_vertices[-_ia - 1] if _ia < 0 else vertices[_ia]
	var point_b: Vector3 = border_vertices[-_ib - 1] if _ib < 0 else vertices[_ib]
	var point_c: Vector3 = border_vertices[-_ic - 1] if _ic < 0 else vertices[_ic]
	
	var side_a_b: Vector3 = point_b - point_a
	var side_a_c: Vector3 = point_c - point_a
	return side_a_b.cross(side_a_c).normalized()
	

func bake_normals():
	baked_normals = calculate_vertex_normals()

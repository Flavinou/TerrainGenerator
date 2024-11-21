extends RefCounted

class_name MeshData

var vertices: PackedVector3Array
var uvs: PackedVector2Array
var triangles: PackedInt32Array

var triangle_index: int

func _init(_width: int, _height: int):
	vertices = PackedVector3Array()
	vertices.resize(_width * _height)
	
	triangles = PackedInt32Array()
	triangles.resize((_width - 1) * (_height - 1) * 6)
	
	uvs = PackedVector2Array()
	uvs.resize(_width * _height)


func add_triangle(a: int, b: int, c: int) -> void:
	triangles[triangle_index] = a
	triangles[triangle_index + 1] = b
	triangles[triangle_index + 2] = c
	triangle_index += 3


func create_mesh() -> ArrayMesh:
	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = triangles
	surface_array[Mesh.ARRAY_NORMAL] = calculate_normals()

	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return arr_mesh

func calculate_normals() -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	
	var triangle_count: int = triangles.size() / 3
	for i in range(triangle_count):
		var normal_triangle_index: int = i * 3
		var vertex_index_a: int = triangles[normal_triangle_index]
		var vertex_index_b: int = triangles[normal_triangle_index + 1]
		var vertex_index_c: int = triangles[normal_triangle_index + 2]
		
		var triangle_normal: Vector3 = surface_normal_from_indices(vertex_index_a, vertex_index_b, vertex_index_c)
		normals[vertex_index_a] += triangle_normal
		normals[vertex_index_b] += triangle_normal
		normals[vertex_index_c] += triangle_normal
		
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	
	return normals
	
func surface_normal_from_indices(_ia: int, _ib: int, _ic: int) -> Vector3:
	var point_a: Vector3 = vertices[_ia]
	var point_b: Vector3 = vertices[_ib]
	var point_c: Vector3 = vertices[_ic]
	
	var side_a_b: Vector3 = point_b - point_a
	var side_a_c: Vector3 = point_c - point_a
	return side_a_b.cross(side_a_c).normalized()
	

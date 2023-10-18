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

	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return arr_mesh

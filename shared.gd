extends Node

@onready var viewer: Node = get_node("/root/TerrainGenerator/Viewer")

var viewer_position: Vector2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	viewer_position = Vector2(viewer.position.x, viewer.position.z)

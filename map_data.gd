extends RefCounted

class_name MapData

var height_map: Array[Array]
var color_map: Array[Color]

func _init(_height_map: Array[Array], _color_map: Array[Color]):
	height_map = _height_map
	color_map = _color_map

@tool
extends Resource

class_name Updatable

@export var auto_update: bool

static func _get_tool_buttons() -> Array:
	return [
		"update"
	]
	

func update() -> void:
	emit_changed()

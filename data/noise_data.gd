@tool
extends Updatable

class_name NoiseData

@export var normalize_mode: Shared.NormalizeMode:
	get:
		return normalize_mode
	set(value):
		normalize_mode = value
		if (auto_update):
			emit_changed()

@export_range(0.001, 30) var noise_scale: float:
	get:
		return noise_scale
	set(value):
		noise_scale = value
		if (auto_update):
			emit_changed()

@export_range(0, 10) var octaves: int:
	get:
		return octaves
	set(value):
		octaves = value
		if (auto_update):
			emit_changed()
		
@export_range(0, 1) var persistance: float:
	get:
		return persistance
	set(value):
		persistance = value
		if (auto_update):
			emit_changed()
		
@export_range(1, 5) var lacunarity: float:
	get:
		return lacunarity
	set(value):
		lacunarity = value
		if (auto_update):
			emit_changed()
		
@export var random_seed: int:
	get:
		return random_seed
	set(value):
		random_seed = value
		if (auto_update):
			emit_changed()
		
@export var offset: Vector2:
	get:
		return offset
	set(value):
		offset = value
		if (auto_update):
			emit_changed()
		
func _init(_normalize_mode: Shared.NormalizeMode = Shared.NormalizeMode.Global, _noise_scale: float = 0.3, _octaves: int = 4, _persistance: float = 0.5, _lacunarity: float = 2.0, _random_seed: int = 0, _offset: Vector2 = Vector2.ZERO):
	normalize_mode = _normalize_mode
	noise_scale = _noise_scale
	octaves = _octaves
	persistance = _persistance
	lacunarity = lacunarity
	random_seed = _random_seed
	offset = _offset
	

@tool
extends Node3D

class_name TerrainGenerator

const FLOAT_MAX: float = 1.79769e308
const FLOAT_MIN: float = -1.79769e308

const MAP_CHUNK_SIZE: int = 241

signal changed(new_value)

@export var draw_mode: DrawMode.DrawMode = DrawMode.DrawMode.ColorMap:
	get:
		return draw_mode
	set(value):
		if (auto_update):
			changed.emit(value)
		draw_mode = value

@export_category("Noise Settings")
@export_range(0, 6) var level_of_detail: int = 0:
	get:
		return level_of_detail
	set(value):
		if (auto_update):
			changed.emit(value)
		level_of_detail = value

@export_range(1, 50) var height_multiplier: float = 1:
	get:
		return height_multiplier
	set(value):
		if (auto_update):
			changed.emit(value)
		height_multiplier = value
		
@export var mesh_height_curve: Curve:
	get:
		return mesh_height_curve
	set(value):
		if (auto_update):
			changed.emit(value)
		mesh_height_curve = value
		
@export_range(0.001, 30) var noise_scale: float = 0.3:
	get:
		return noise_scale
	set(value):
		if (auto_update):
			changed.emit(value)
		noise_scale = value

@export_range(0, 10) var octaves: int = 4:
	get:
		return octaves
	set(value):
		if (auto_update):
			changed.emit(value)
		octaves = value
		
@export_range(0, 1) var persistance: float = 0.5:
	get:
		return persistance
	set(value):
		if (auto_update):
			changed.emit(value)
		persistance = value
		
@export_range(1, 5) var lacunarity: float = 2:
	get:
		return lacunarity
	set(value):
		if (auto_update):
			changed.emit(value)
		lacunarity = value
		
@export var random_seed: int:
	get:
		return random_seed
	set(value):
		if (auto_update):
			changed.emit(value)
		random_seed = value
		
@export var offset: Vector2:
	get:
		return offset
	set(value):
		if (auto_update):
			changed.emit(value)
		offset = value
		
@export var auto_update: bool = false

@export var regions: Array[TerrainType] = []:
	get:
		return regions
	set(value):
		if (auto_update):
			changed.emit(value)
		regions = value

# Internals
var rng: RandomNumberGenerator
var noise: FastNoiseLite

	
func _init():
	if rng == null:
		rng = RandomNumberGenerator.new()
	if noise == null:
		noise = FastNoiseLite.new()
		
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	
func _get_tool_buttons() -> Array:
	return [
		"draw_map_in_editor"
	]
	

func _on_button_pressed():
	draw_map_in_editor()


func _on_changed(_new_value):
	draw_map_in_editor()
	

func draw_map_in_editor() -> void:
	var display: TerrainDisplay = get_node("TerrainDisplay")
	if display == null:
		print("No 'TerrainDisplay' node found, cannot draw map.")
		return
		
	var mesh_display: MeshDisplay = get_node("MeshDisplay")
	if mesh_display == null:
		print("No 'MeshDisplay' node found, cannot draw mesh.")
		return
		
	var map_data: MapData = generate_map_data()
	
	match draw_mode:
		DrawMode.DrawMode.NoiseMap:
			display.draw_texture(texture_from_height_map(map_data.height_map, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE))
		DrawMode.DrawMode.ColorMap:
			display.draw_texture(texture_from_color_map(map_data.color_map, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE))
		DrawMode.DrawMode.Mesh:
			mesh_display.draw_mesh(
				generate_terrain_mesh(map_data.height_map, height_multiplier, mesh_height_curve, level_of_detail, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE), 
				texture_from_color_map(map_data.color_map, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE)
			)
		_: 
			return # ignore other possibilities at the moment


func request_map_data(callback: Callable) -> void:
	var thread: Thread = Thread.new()
	thread.start(map_data_thread.bind(callback))
	
func map_data_thread(callback: Callable) -> void:
	var map_data: MapData = generate_map_data()
	# TODO : add locking mechanism

func generate_map_data() -> MapData:
	var noise_map: Array[Array] = generate_noise_map(MAP_CHUNK_SIZE, MAP_CHUNK_SIZE, random_seed, noise_scale, octaves, persistance, lacunarity, offset)
	
	# assign colors to each region
	var color_map: Array[Color] = []
	color_map.resize(MAP_CHUNK_SIZE * MAP_CHUNK_SIZE)
	for x in range(MAP_CHUNK_SIZE):
		for y in range(MAP_CHUNK_SIZE):
			var current_height: float = noise_map[x][y]
			for i in range(regions.size()):
				if current_height <= regions[i].height:
					color_map[y * MAP_CHUNK_SIZE + x] = regions[i].color
					break
	
	return MapData.new(noise_map, color_map)

# generate a 2-dimensional array of random values for the specified resolution and scale
func generate_noise_map(_width: int, _height: int, _seed: int, _texture_scale: float, _octaves: int, _persistance: float, _lacunarity: float, _offset: Vector2) -> Array[Array]:
	rng.seed = _seed
	
	var noise_map: Array[Array] = []
	
	var octaveOffsets: PackedVector2Array = []
	octaveOffsets.resize(_octaves)
	for i in range(_octaves):
		var offsetX: float = rng.randi_range(-100000, 100000) + offset.x
		var offsetY: float = rng.randi_range(-100000, 100000) + offset.y
		octaveOffsets[i] = Vector2(offsetX, offsetY)
		
	if _texture_scale <= 0:
		_texture_scale = 0.0001
		
	var max_noise_height: float = FLOAT_MIN
	var min_noise_height: float = FLOAT_MAX
	
	var half_width: float = _width / 2.0
	var half_height: float = _height / 2.0
	
	for x in range(_width):
		noise_map.append([])
		
		for y in range(_height):
			noise_map[x].append(0)
			
			var amplitude: float = 1
			var frequency: float = 1
			var noise_height: float = 0
			
			for i in range(_octaves):
				var sample_x: float = (x - half_width) / _texture_scale * frequency + octaveOffsets[i].x
				var sample_y: float = (y - half_height) / _texture_scale * frequency + octaveOffsets[i].y
				
				var noise_value: float = noise.get_noise_2d(sample_x, sample_y) * 2 - 1
				noise_height += noise_value * amplitude
				
				amplitude *= _persistance
				frequency *= _lacunarity
			
			if noise_height > max_noise_height:
				max_noise_height = noise_height
			elif noise_height < min_noise_height:
				min_noise_height = noise_height
			
			noise_map[x][y] = noise_height
				
	for x in range(_width):
		for y in range(_height):
			# normalize noise map
			noise_map[x][y] = inverse_lerp(min_noise_height, max_noise_height, noise_map[x][y])
			
	return noise_map

# generate a mesh from a 2-dimensional height map
func generate_terrain_mesh(_height_map: Array[Array], _height_multiplier: float, _height_curve: Curve, _level_of_detail: int, _width: int, _height: int) -> MeshData:
	var top_left_x: float = (_width - 1) / -2.0
	var top_left_z: float = (_height - 1) / 2.0
	
	var meshSimplificationIncrement: int = 1 if _level_of_detail == 0 else _level_of_detail * 2
	var verticesPerLine: int = ( (_width - 1) / meshSimplificationIncrement ) + 1
	
	var mesh_data: MeshData = MeshData.new(verticesPerLine, verticesPerLine)
	var vertex_index: int = 0
	
	if not _height_curve:
		push_warning("No height curve set, raw points from height map will be used.")
	
	for x in range(0, _width, meshSimplificationIncrement):
		for y in range(0, _height, meshSimplificationIncrement):
			var y_axis_value: float = _height_curve.sample(_height_map[x][y]) if _height_curve else _height_map[x][y]
			mesh_data.vertices[vertex_index] = Vector3(top_left_x + x, y_axis_value * _height_multiplier, top_left_z - y)
			mesh_data.uvs[vertex_index] = Vector2(x / (_width as float), y / (_height as float))
			
			if x < _width - 1 and y < _height - 1:
				mesh_data.add_triangle(vertex_index, vertex_index + verticesPerLine + 1, vertex_index + verticesPerLine)
				mesh_data.add_triangle(vertex_index + verticesPerLine + 1, vertex_index, vertex_index + 1)

			vertex_index += 1
			
	return mesh_data

# Utilities #

func texture_from_color_map(_color_map: Array[Color], _width: int, _height: int) -> ImageTexture:
	var image: Image = Image.create(_width, _height, false, Image.FORMAT_RGBA8)
	
	for x in range(_width):
		for y in range(_height):
			image.set_pixel(x, y, _color_map[y * _width + x])
			
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return texture
	
func texture_from_height_map(_height_map: Array[Array], _width: int, _height: int) -> ImageTexture:
	var color_map: Array[Color] = []
	color_map.resize(_width * _height)
	for x in range(_width):
		for y in range(_height):
			color_map[y * _width + x] = lerp(Color.BLACK, Color.WHITE, _height_map[x][y])
			
	return texture_from_color_map(color_map, _width, _height)

@tool
extends Node3D

class_name TerrainGenerator

const FLOAT_MAX: float = 1.79769e308
const FLOAT_MIN: float = -1.79769e308
const INT_MAX: float = 9223372036854775807
const INT_MIN: float = -9223372036854775808

const MAP_CHUNK_SIZE: int = 241

signal changed(new_value)

@export var draw_mode: DrawMode.DrawMode:
	get:
		return draw_mode
	set(value):
		if (auto_update):
			changed.emit(value)
		draw_mode = value
		
@export var normalize_mode: Shared.NormalizeMode:
	get:
		return normalize_mode
	set(value):
		if (auto_update):
			changed.emit(value)
		normalize_mode = value

@export_category("Noise Settings")
@export_range(0, 6) var editor_preview_lod: int = 0:
	get:
		return editor_preview_lod
	set(value):
		if (auto_update):
			changed.emit(value)
		editor_preview_lod = value

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
@export var use_falloff: bool = false

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

# Queue<ThreadOperation<MapData | MeshData>>
var result_queue: Array = []
var task_queue: Array = []

var thread_pool: Array = []
var max_threads: int = 2
var max_chunks_per_frame: int = 2

var lock: Mutex
var semaphore: Semaphore
var is_running: bool = true

# State
var falloff_map: Array[Array] # 2d float array
	
func _init():
	if rng == null:
		rng = RandomNumberGenerator.new()
	if noise == null:
		noise = FastNoiseLite.new()
		
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	falloff_map = TerrainGenerator.generate_falloff_map(MAP_CHUNK_SIZE)
	
	
func _ready():
	lock = Mutex.new()
	semaphore = Semaphore.new()
	
	for i in range(max_threads):
		var worker_thread = Thread.new()
		thread_pool.append(worker_thread)
		worker_thread.start(thread_worker_callback)
	
	
func _process(_delta):
	lock.lock()
	if (result_queue.size() > 0):
		# Pop element from the queue and run its callback method
		for i in range(min(max_chunks_per_frame, result_queue.size())):
			var result = result_queue.pop_front() as ThreadOperation
			
			result.callback.call_deferred(result.arg)
	lock.unlock()
	
	
func _get_tool_buttons() -> Array:
	return [
		"draw_map_in_editor"
	]
	

func _on_button_pressed():
	draw_map_in_editor()


func _on_changed(_new_value):
	draw_map_in_editor()
	
	
func _exit_tree():
	is_running = false
	for i in range(max_threads):
		semaphore.post()  # Unblock all threads gracefully
	for thread in thread_pool:
		thread.wait_to_finish()
	
	
func draw_map_in_editor() -> void:
	var display: TerrainDisplay = get_node("TerrainDisplay")
	if display == null:
		print("No 'TerrainDisplay' node found, cannot draw map.")
		return
		
	var mesh_display: MeshDisplay = get_node("MeshDisplay")
	if mesh_display == null:
		print("No 'MeshDisplay' node found, cannot draw mesh.")
		return
		
	var map_data: MapData = generate_map_data(Vector2.ZERO)
	
	match draw_mode:
		DrawMode.DrawMode.NoiseMap:
			display.draw_texture(TerrainGenerator.texture_from_height_map(map_data.height_map, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE))
		DrawMode.DrawMode.ColorMap:
			display.draw_texture(TerrainGenerator.texture_from_color_map(map_data.color_map, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE))
		DrawMode.DrawMode.Mesh:
			mesh_display.draw_mesh(
				generate_terrain_mesh(map_data.height_map, height_multiplier, mesh_height_curve, editor_preview_lod, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE), 
				TerrainGenerator.texture_from_color_map(map_data.color_map, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE)
			)
		DrawMode.DrawMode.FalloffMap:
			display.draw_texture(TerrainGenerator.texture_from_height_map(TerrainGenerator.generate_falloff_map(MAP_CHUNK_SIZE), MAP_CHUNK_SIZE, MAP_CHUNK_SIZE))
		_: 
			return # ignore other possibilities at the moment


func generate_map_data(center: Vector2) -> MapData:
	var noise_map: Array[Array] = generate_noise_map(MAP_CHUNK_SIZE, MAP_CHUNK_SIZE, random_seed, noise_scale, octaves, persistance, lacunarity, center + offset, normalize_mode)
	
	# assign colors to each region
	var color_map: Array[Color] = []
	color_map.resize(MAP_CHUNK_SIZE * MAP_CHUNK_SIZE)
	for x in range(MAP_CHUNK_SIZE):
		for y in range(MAP_CHUNK_SIZE):
			if use_falloff:
				noise_map[x][y] = clamp(noise_map[x][y] - falloff_map[x][y], 0, 1)
			var current_height: float = noise_map[x][y]
			for i in range(regions.size()):
				if current_height >= regions[i].height:
					color_map[y * MAP_CHUNK_SIZE + x] = regions[i].color
				else:
					break
	
	return MapData.new(noise_map, color_map)


# generate a 2-dimensional array of random values for the specified resolution and scale
func generate_noise_map(_width: int, _height: int, _seed: int, _texture_scale: float, _octaves: int, _persistance: float, _lacunarity: float, _offset: Vector2, _normalize_mode: Shared.NormalizeMode) -> Array[Array]:
	rng.seed = _seed
	
	var noise_map: Array[Array] = []
	var octaveOffsets: PackedVector2Array = []
	octaveOffsets.resize(_octaves)
	
	var max_possible_noise_height: float = 0
	var amplitude: float = 1
	var frequency: float = 1
	
	for i in range(_octaves):
		var offsetX: float = rng.randi_range(-100000, 100000) + _offset.x
		var offsetY: float = rng.randi_range(-100000, 100000) - _offset.y
		octaveOffsets[i] = Vector2(offsetX, offsetY)
		
		max_possible_noise_height += amplitude
		amplitude *= _persistance
		
	if _texture_scale <= 0:
		_texture_scale = 0.0001
		
	var max_local_noise_height: float = FLOAT_MIN
	var min_local_noise_height: float = FLOAT_MAX
	
	var half_width: float = _width / 2.0
	var half_height: float = _height / 2.0
	
	for x in range(_width):
		noise_map.append([])
		
		for y in range(_height):
			noise_map[x].append(0)
			
			amplitude = 1
			frequency = 1
			var noise_height: float = 0
			
			for i in range(_octaves):
				var sample_x: float = (x - half_width + octaveOffsets[i].x) / _texture_scale * frequency
				var sample_y: float = (y - half_height + octaveOffsets[i].y) / _texture_scale * frequency
				
				var noise_value: float = noise.get_noise_2d(sample_x, sample_y) * 2 - 1
				noise_height += noise_value * amplitude
				
				amplitude *= _persistance
				frequency *= _lacunarity
			
			if noise_height > max_local_noise_height:
				max_local_noise_height = noise_height
			elif noise_height < min_local_noise_height:
				min_local_noise_height = noise_height
			
			noise_map[x][y] = noise_height
				
	for x in range(_width):
		for y in range(_height):
			if _normalize_mode == Shared.NormalizeMode.Local:
				noise_map[x][y] = inverse_lerp(min_local_noise_height, max_local_noise_height, noise_map[x][y])
			else:
				var normalized_height: float = (noise_map[x][y] + 1) / (max_possible_noise_height / 1.25)
				noise_map[x][y] = clamp(normalized_height, 0, INT_MAX)
			
	return noise_map


# generate a mesh from a 2-dimensional height map
func generate_terrain_mesh(_height_map: Array[Array], _height_multiplier: float, _height_curve: Curve, _level_of_detail: int, _width: int, _height: int) -> MeshData:
	var height_curve: Curve = _height_curve.duplicate()
	var top_left_x: float = (_width - 1) / -2.0
	var top_left_z: float = (_height - 1) / 2.0
	
	var meshSimplificationIncrement: int = 1 if _level_of_detail == 0 else _level_of_detail * 2
	@warning_ignore("integer_division")
	var verticesPerLine: int = ( (_width - 1) / meshSimplificationIncrement ) + 1
	
	var mesh_data: MeshData = MeshData.new(verticesPerLine, verticesPerLine)
	var vertex_index: int = 0
	
	if not height_curve:
		push_warning("No height curve set, raw points from height map will be used.")
	
	for x in range(0, _width, meshSimplificationIncrement):
		for y in range(0, _height, meshSimplificationIncrement):
			var y_axis_value: float = height_curve.sample(_height_map[x][y]) if height_curve else _height_map[x][y]
			mesh_data.vertices[vertex_index] = Vector3(top_left_x + x, y_axis_value * _height_multiplier, top_left_z - y)
			mesh_data.uvs[vertex_index] = Vector2(x / (_width as float), y / (_height as float))
			
			if x < _width - 1 and y < _height - 1:
				mesh_data.add_triangle(vertex_index, vertex_index + verticesPerLine + 1, vertex_index + verticesPerLine)
				mesh_data.add_triangle(vertex_index + verticesPerLine + 1, vertex_index, vertex_index + 1)

			vertex_index += 1
			
	return mesh_data


static func generate_falloff_map(_size: int) -> Array[Array]:
	var map: Array[Array] = []
	
	for i in range(_size):
		map.append([])
		
		for j in range(_size):
			map[i].append(0)
			var x: float = i / float(_size) * 2 - 1
			var y: float = j / float(_size) * 2 - 1
			
			var value: float = max(abs(x), abs(y))
			map[i][j] = evaluate(value)
			
	return map
	

static func evaluate(_value: float) -> float:
	var a: float = 3
	var b: float = 2.2
	
	return pow(_value, a) / (pow(_value, a) + pow((b - b * _value), a))

# Utilities #

static func texture_from_color_map(_color_map: Array[Color], _width: int, _height: int) -> ImageTexture:
	var image: Image = Image.create(_width, _height, false, Image.FORMAT_RGBA8)
	
	for x in range(_width):
		for y in range(_height):
			image.set_pixel(x, y, _color_map[y * _width + x])
			
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return texture
	
	
static func texture_from_height_map(_height_map: Array[Array], _width: int, _height: int) -> ImageTexture:
	var color_map: Array[Color] = []
	color_map.resize(_width * _height)
	for x in range(_width):
		for y in range(_height):
			color_map[y * _width + x] = lerp(Color.BLACK, Color.WHITE, _height_map[x][y])
			
	return texture_from_color_map(color_map, _width, _height)
	

# Threading Utilities #

func thread_worker_callback() -> void:
	while is_running:
		semaphore.wait()
		lock.lock()
		if task_queue.size() > 0:
			var task = task_queue.pop_front() as Callable
			task.call_deferred()
		else:
			lock.unlock()
			continue
		lock.unlock()
	
	
func request_map_data(center: Vector2, completed_callback: Callable) -> void:
	lock.lock()
	task_queue.append(map_data_thread.bind(center, completed_callback))
	lock.unlock()
	semaphore.post()
	
	
# Will be executed on another thread
func map_data_thread(center: Vector2, completed_callback: Callable) -> void:
	var map_data: MapData = generate_map_data(center)
	var map_task: ThreadOperation = ThreadOperation.new(completed_callback, map_data)
	
	lock.lock()
	result_queue.append(map_task)
	lock.unlock()
	
	
func request_mesh_data(map_data: MapData, lod: int, completed_callback: Callable) -> void:
	lock.lock()
	task_queue.append(mesh_data_thread.bind(map_data, lod, completed_callback))
	lock.unlock()
	semaphore.post()
	
	
# Will be executed on another thread
func mesh_data_thread(map_data: MapData, lod: int, completed_callback: Callable) -> void:
	var mesh_data: MeshData = generate_terrain_mesh(map_data.height_map, height_multiplier, mesh_height_curve, lod, MAP_CHUNK_SIZE, MAP_CHUNK_SIZE)
	var mesh_task: ThreadOperation = ThreadOperation.new(completed_callback, mesh_data)
	
	lock.lock()
	result_queue.append(mesh_task)
	lock.unlock()

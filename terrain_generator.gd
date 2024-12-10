@tool
extends Node3D

class_name TerrainGenerator

@onready var terrain_display: TerrainDisplay = get_node("TerrainDisplay")
@onready var mesh_display: MeshDisplay = get_node("MeshDisplay")

@export var terrain_data: TerrainData
@export var noise_data: NoiseData
@export var texture_data: TextureData

@export var terrain_material: ShaderMaterial

signal changed()

var map_chunk_size: int:
	get:
		return 95 if terrain_data != null and terrain_data.use_flat_shading else 239
		
@export var draw_mode: DrawMode.DrawMode:
	get:
		return draw_mode
	set(value):
		if (auto_update):
			changed.emit()
		draw_mode = value

@export_category("Noise Settings")
@export_range(0, 6) var editor_preview_lod: int = 0:
	get:
		return editor_preview_lod
	set(value):
		if (auto_update):
			changed.emit()
		editor_preview_lod = value
		
@export var auto_update: bool = false

# Internals
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var noise: FastNoiseLite = FastNoiseLite.new()

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
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	
func _ready():
	# init main worker thread
	lock = Mutex.new()
	semaphore = Semaphore.new()
	
	for i in range(max_threads):
		var worker_thread = Thread.new()
		thread_pool.append(worker_thread)
		worker_thread.start(thread_worker_callback)
		
	# connect terrain and noise "changed" signals
	if terrain_data != null and not terrain_data.changed.is_connected(_on_changed):
		terrain_data.changed.connect(_on_changed)
		
	if noise_data != null and not noise_data.changed.is_connected(_on_changed):
		noise_data.changed.connect(_on_changed)
		
	if texture_data != null and not texture_data.changed.is_connected(_on_changed):
		texture_data.changed.connect(_on_texture_changed)
	
	
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


func _on_texture_changed():
	texture_data.apply_to_material(terrain_material)


func _on_changed():
	draw_map_in_editor()
	
	
func _exit_tree():
	is_running = false
	for i in range(max_threads):
		semaphore.post()  # Unblock all threads gracefully
	for thread in thread_pool:
		thread.wait_to_finish()
	
	
func draw_map_in_editor() -> void:
	if terrain_display == null or mesh_display == null:
		print("'TerrainDisplay' or 'MeshDisplay' node is missing, cannot draw map.")
		return
		
	var map_data: MapData = generate_map_data(Vector2.ZERO)
	
	match draw_mode:
		DrawMode.DrawMode.NoiseMap:
			terrain_display.draw_texture(TerrainGenerator.texture_from_height_map(map_data.height_map, map_chunk_size, map_chunk_size))
		DrawMode.DrawMode.Mesh:
			mesh_display.draw_mesh(
				generate_terrain_mesh(map_data.height_map, terrain_data.height_multiplier, terrain_data.mesh_height_curve, editor_preview_lod, terrain_data.use_flat_shading)
			)
		DrawMode.DrawMode.FalloffMap:
			terrain_display.draw_texture(TerrainGenerator.texture_from_height_map(TerrainGenerator.generate_falloff_map(map_chunk_size), map_chunk_size, map_chunk_size))
		_: 
			return # ignore other possibilities at the moment


func generate_map_data(center: Vector2) -> MapData:
	var noise_map: Array[Array] = generate_noise_map(map_chunk_size + 2, map_chunk_size + 2, noise_data.random_seed, noise_data.noise_scale, noise_data.octaves, noise_data.persistance, noise_data.lacunarity, center + noise_data.offset, noise_data.normalize_mode)
	
	if terrain_data.use_falloff:
		if falloff_map == null:
			falloff_map = TerrainGenerator.generate_falloff_map(map_chunk_size + 2)
		
		# assign colors to each region
		for x in range(map_chunk_size + 2):
			for y in range(map_chunk_size + 2):
				if terrain_data.use_falloff:
					noise_map[x][y] = clamp(noise_map[x][y] - falloff_map[x][y], 0, 1)
	
	texture_data.update_mesh_heights(terrain_material, terrain_data.min_height, terrain_data.max_height)
	
	return MapData.new(noise_map)


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
		
	var max_local_noise_height: float = Shared.FLOAT_MIN
	var min_local_noise_height: float = Shared.FLOAT_MAX
	
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
				noise_map[x][y] = clamp(normalized_height, 0, Shared.INT_MAX)
			
	return noise_map


# generate a mesh from a 2-dimensional height map
func generate_terrain_mesh(_height_map: Array[Array], _height_multiplier: float, _height_curve: Curve, _level_of_detail: int, _use_flat_shading: bool) -> MeshData:
	var height_curve: Curve = _height_curve.duplicate()
	
	var mesh_simplification_increment: int = 1 if _level_of_detail == 0 else _level_of_detail * 2
	
	var bordered_size: int = _height_map.size()
	var mesh_size: int = bordered_size - 2 * mesh_simplification_increment
	var mesh_size_unsimplified: int = bordered_size - 2
	
	var top_left_x: float = (mesh_size_unsimplified - 1) / -2.0
	var top_left_z: float = (mesh_size_unsimplified - 1) / 2.0
	
	@warning_ignore("integer_division")
	var vertices_per_line: int = (mesh_size - 1) / mesh_simplification_increment + 1
	
	var mesh_data: MeshData = MeshData.new(vertices_per_line, _use_flat_shading)

	var vertex_indices_map: Array[Array] = []
	vertex_indices_map.resize(bordered_size)
	var mesh_vertex_index: int = 0
	var border_vertex_index: int = -1
	
	for y in range(0, bordered_size, mesh_simplification_increment):
		for x in range(0, bordered_size, mesh_simplification_increment):
			if vertex_indices_map[x].size() == 0:
				vertex_indices_map[x].resize(bordered_size)
			
			var is_border_vertex: bool = y == 0 or y == bordered_size - 1 or x == 0 or x == bordered_size - 1
			if is_border_vertex:
				vertex_indices_map[x][y] = border_vertex_index
				border_vertex_index -= 1
			else:
				vertex_indices_map[x][y] = mesh_vertex_index
				mesh_vertex_index += 1
	
	if not height_curve:
		push_warning("No height curve set, raw points from height map will be used.")
	
	for y in range(0, bordered_size, mesh_simplification_increment):
		for x in range(0, bordered_size, mesh_simplification_increment):
			var vertex_index: int = vertex_indices_map[x][y]
			var percent: Vector2 = Vector2((x - mesh_simplification_increment) / (mesh_size as float), (y - mesh_simplification_increment) / (mesh_size as float))
			var height: float = ( height_curve.sample(_height_map[x][y]) if height_curve else _height_map[x][y] ) * _height_multiplier
			var vertex_position: Vector3 = Vector3(top_left_x + percent.x * mesh_size_unsimplified, height, top_left_z - percent.y * mesh_size_unsimplified)
			
			mesh_data.add_vertex(vertex_position, percent, vertex_index)
			
			if x < bordered_size - 1 and y < bordered_size - 1:
				var a: int = vertex_indices_map[x][y]
				var b: int = vertex_indices_map[x + mesh_simplification_increment][y]
				var c: int = vertex_indices_map[x][y + mesh_simplification_increment]
				var d: int = vertex_indices_map[x + mesh_simplification_increment][y + mesh_simplification_increment]
				mesh_data.add_triangle(b, c, d) # Godot (Vulkan API) wants it counter-clockwise apparently
				mesh_data.add_triangle(c, b, a)

			vertex_index += 1
			
	mesh_data.process_mesh()
			
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
	var mesh_data: MeshData = generate_terrain_mesh(map_data.height_map, terrain_data.height_multiplier, terrain_data.mesh_height_curve, lod, terrain_data.use_flat_shading)
	var mesh_task: ThreadOperation = ThreadOperation.new(completed_callback, mesh_data)
	
	lock.lock()
	result_queue.append(mesh_task)
	lock.unlock()

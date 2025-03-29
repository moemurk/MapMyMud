extends MeshInstance3D

const MAP_WIDTH = 128 #default=32
const MAP_HEIGHT = 128
var height_map = []
@onready var colShape = $StaticBody3D/CollisionShape3D
@export var mesh_size = 20.0
@export var height_ratio = 0.3 #default=0.3 (for size 2.0)
@export var colShape_size_ratio = 5.0 #mesh finess, default=1.0

func _ready():
	height_map = generate_heightmap_by_noise()
	var pos = generate_start_end()
	var path_num = 1 #default =5
	var paths = generate_paths(pos[0], pos[1], path_num)
	print("start and end is:",pos)
	print("paths are:",paths)
	var flatten_radius = 1.0 #default = 1.0
	flatten_paths_in_height_map(paths, flatten_radius)
	var image = Image.create(MAP_WIDTH, MAP_HEIGHT, false, Image.FORMAT_RGB8)
	image = texture_override(image)
	var shape = HeightMapShape3D.new()
	shape = generate_collider_shape(shape, image)
	
	
func generate_heightmap_by_noise():
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05 
	noise.fractal_gain = 0.8 
	noise.fractal_octaves = 4 
	height_map.resize(MAP_WIDTH)
	for x in range(MAP_WIDTH):
		height_map[x] = []
		for y in range(MAP_HEIGHT):
			var value = noise.get_noise_2d(x, y)
			height_map[x].append(value)
	return height_map
	
func texture_override(image):
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var value = height_map[x][y]
			var gray = clamp((value + 1.0) / 2.0, 0, 1)
			image.set_pixel(x, y, Color(gray,gray,gray))
	var texture = ImageTexture.create_from_image(image)
	#var sprite = Sprite2D.new()
	#sprite.scale = Vector2(10,10)
	#sprite.position=Vector2(500,500)
	#sprite.texture = texture
	#add_child(sprite)
	var address = "user://height_map.exr"
	image.save_exr(address)
	var height_texture = ImageTexture.create_from_image(image)
	material_override.set_shader_parameter("heightmap", height_texture)
	return image

func generate_collider_shape(shape, image):
	mesh.size = Vector2(mesh_size, mesh_size)
	var collision_img = image.duplicate()
	collision_img.convert(Image.FORMAT_RF)
	collision_img.resize(collision_img.get_width()*colShape_size_ratio, collision_img.get_height()*colShape_size_ratio)
	var data = collision_img.get_data().to_float32_array()
	for i in range(0, data.size()):
		data[i] *= height_ratio
	shape.map_width = collision_img.get_width()
	shape.map_depth = collision_img.get_height()
	shape.map_data = data
	var scale_ratio = mesh_size/float(collision_img.get_width())
	colShape.scale = Vector3(scale_ratio, 1, scale_ratio)
	colShape.shape = shape
	return shape

func generate_start_end():
	var start_x = randi() % MAP_WIDTH
	var start_y = randi() % MAP_HEIGHT
	var start_pos = Vector2(start_x, start_y)
	var end_pos = start_pos
	while end_pos.distance_to(start_pos) < (MAP_WIDTH / 2.0):
		var end_x = randi() % MAP_WIDTH
		var end_y = randi() % MAP_HEIGHT
		end_pos = Vector2(end_x, end_y)
	return [start_pos, end_pos]

func generate_paths(start:Vector2, end:Vector2, num_paths:int):
	var paths = []
	for i in range(num_paths):
		var path = []
		var current_pos = start
		path.append(current_pos)
		while current_pos.distance_to(end) > 2.0: #stop when close enough
			var direction = (end - current_pos).normalized()
			var random_offset = Vector2(randf() - 0.5, randf() - 0.5) * 2
			var next_step = current_pos + (direction + random_offset) * 1.0 #default=3.0
			next_step.x = clamp(next_step.x, 0, MAP_WIDTH - 1)
			next_step.y = clamp(next_step.y, 0, MAP_HEIGHT - 1)
			current_pos = next_step
			path.append(current_pos)
		path.append(end)
		paths.append(path)
	return paths

func flatten_paths_in_height_map(paths: Array, radius: float = 1.0):
	for path in paths:
		for pt in path:
			var px = int(pt.x)
			var py = int(pt.y)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var nx = px + dx
					var ny = py + dy
					if nx >= 0 and nx < MAP_WIDTH and ny >= 0 and ny < MAP_HEIGHT:
						# (Optional) If you want a circular fade, you can check distance:
						# if Vector2(dx, dy).length() <= float(radius):
						#     height_map[nx][ny] = -1.0
						
						# For a simple square, just flatten:
						height_map[nx][ny] = -5.0

extends MeshInstance3D

const MAP_WIDTH = 128 #default=32
const MAP_HEIGHT = 128
var height_map = []
@onready var colShape = $StaticBody3D/CollisionShape3D
@export var mesh_size = 20.0
@export var height_ratio = 0.3 #default=0.3 (for size 2.0)
@export var colShape_size_ratio = 5.0 #mesh finess, default=1.0

@export var ctrl_spacing = 2.0 #anchor points spacing, default=2.0
@export var lat_offset_max = 6.0 #max horizontal offset(grid), default=10.0
@export var bake_step = 1.2 #curve sampling step(grid), default=1.5

var road_depth = -5.0
var road_half_width = 0.6 
var edge_falloff = 0.5

var start_world : Vector3
var end_world : Vector3
signal map_ready(start_world : Vector3, end_world : Vector3)

func _ready():
	height_map = generate_heightmap_by_noise()
	
	var road_gen = RoadNetGenerator.new()
	road_gen.map_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	add_child(road_gen)
	await road_gen.ready
	var paths = road_gen.paths
	var start_grid = road_gen.start_point
	var goad_grid = road_gen.goal_point
	
	#var pos = generate_start_end()
	#var path_num = 1 #default =5
	#var paths = generate_paths(pos[0], pos[1], path_num)
	flatten_paths_in_height_map(paths)
	print(paths)
	var image = Image.create(MAP_WIDTH, MAP_HEIGHT, false, Image.FORMAT_RGB8)
	image = texture_override(image)
	var shape = HeightMapShape3D.new()
	shape = generate_collider_shape(shape, image)
	
	var start_end_y = road_depth + 90.0
	start_world = Vector3(start_grid.x, start_end_y, start_grid.y)
	end_world = Vector3(goad_grid.x, start_end_y, goad_grid.y)
	
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

""" #generate start & end, with paths
func generate_start_end():
	var start_x = randi() % MAP_WIDTH
	var start_y = randi() % MAP_HEIGHT
	var start_pos = Vector2(start_x, start_y)
	
	var end_pos = start_pos
	while end_pos.distance_to(start_pos) < (MAP_WIDTH / 2.0):
		var end_x = randi() % MAP_WIDTH
		var end_y = randi() % MAP_HEIGHT
		end_pos = Vector2(end_x, end_y)
	
	var start_end_y = road_depth + 90.0
	start_world = Vector3(start_pos.x, start_end_y, start_pos.y)
	end_world = Vector3(end_pos.x, start_end_y, end_pos.y)
	return [start_pos, end_pos]

func generate_paths(start:Vector2, end:Vector2, num_paths:int) -> Array:
	var paths = []
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_system()
	
	for p_i in range(num_paths):
		var dir = (end - start).normalized()
		var dist = start.distance_to(end)
		var seg_cnt = int(dist / ctrl_spacing)
		var curve = Curve2D.new()
		curve.add_point(start)
		
		# generating internal anchor points
		for i in range(1, seg_cnt):
			var t = float(i)/ seg_cnt
			var base = start.lerp(end, t)
			var strength = sin(t * PI)
			var perp = Vector2(-dir.y, dir.x)
			var offset = perp * rng.randf_range(-lat_offset_max, lat_offset_max) * strength
			var pt = base + offset
			pt.x = clamp(pt.x, 0, MAP_WIDTH - 1)
			pt.y = clamp(pt.y, 0, MAP_HEIGHT - 1)
			curve.add_point(pt)
		curve.add_point(end)
		curve.bake_interval = bake_step #backing resolution
		var baked = curve.get_baked_points() #Curve2D.tessellate() only return turning points
		
		var path_points = []
		for b in baked:
			path_points.append(Vector2(b.x, b.y))
		paths.append(path_points)
		
	return paths
"""

func flatten_paths_in_height_map(paths: Array):
	for path in paths:
		for pt in path:
			var px = int(pt.x)
			var py = int(pt.y)
			var max_range = ceil(road_half_width + edge_falloff)
			for dx in range(-max_range, max_range + 1):
				for dy in range(-max_range, max_range + 1):
					var nx = px + dx
					var ny = py + dy
					if nx < 0 or nx >= MAP_WIDTH or ny < 0 or ny >= MAP_HEIGHT:
						continue
						#height_map[nx][ny] = -5.0 # for simple square/flatten
					var dist = Vector2(dx, dy).length()   # 0 → radius
					if dist <= road_half_width:
						height_map[nx][ny] = road_depth
					elif dist <= road_half_width + edge_falloff:
						var t = (dist - road_half_width) / edge_falloff  # 0 -> 1
						height_map[nx][ny] = lerp(road_depth, height_map[nx][ny], t) #or smoothstep(t) to make smoother

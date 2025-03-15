extends MeshInstance3D

const MAP_WIDTH = 32
const MAP_HEIGHT = 32
var height_map = []
@onready var colShape = $StaticBody3D/CollisionShape3D
@export var chunk_size = 2.0
@export var height_ratio = 1.0
@export var colShape_size_ratio = 0.1


func _ready():
	# Create height map by noise #
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
	
	# Visualize by image and sprite #
	var image = Image.create(MAP_WIDTH, MAP_HEIGHT, false, Image.FORMAT_RGB8)
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var value = height_map[x][y]
			var gray = clamp((value + 1.0) / 2.0, 0, 1)
			image.set_pixel(x, y, Color(gray,gray,gray))
	var texture = ImageTexture.create_from_image(image)
	var sprite = Sprite2D.new()
	sprite.scale = Vector2(10,10)
	sprite.position=Vector2(500,500)
	sprite.texture = texture
	add_child(sprite)

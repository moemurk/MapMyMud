extends Node2D

class_name RoadNetGenerator

# ───── 可调参数 ────────────────────────────────────────────────
@export var map_size           : Vector2 = Vector2(128, 128)

@export var road_half_width    : float   = 0.6
@export var edge_falloff       : float   = 0.5
const   EXTRA_MARGIN           := 0.4     # 再留一点安全距离
var     clearance              : float

@export var seg_len_min        : float   = 8.0
@export var seg_len_max        : float   = 25.0
@export var min_turn_angle_deg : float   = 15.0
@export var max_turn_angle_deg : float   = 80.0

@export var branch_prob        : float   = 0.25      # 生长点生成子分支概率
@export var branch_angle_min   : float   = 30.0      # 与主方向的夹角范围
@export var branch_angle_max   : float   = 60.0
@export var branch_depth_max   : int     = 2

@export var max_iter           : int     = 1500      # 全局迭代步数上限
@export var max_fail_per_node  : int     = 6         # 单节点尝试生成段的失败上限

@export var debug_draw         : bool    = true      # 2D 视图里画线预览
@export var debug_step         : float   = 1.0       # 采样步长（线条细腻度）
# ──────────────────────────────────────────────────────────────

# 路网结果：paths = Array[ Array[Vector2] ]
var paths : Array
var active_endpoints: Array = []   # 正在生长的端点列表
var start_point : Vector2
var goal_point  : Vector2

# ———————————————————————— Spatial Hash ——————————————————————
class SpatialHash2D:
	var cell_size : float
	var data      : Dictionary
	
	func _init(cs: float) -> void:
		cell_size = cs
		data = {}
	
	func _hash(v: Vector2) -> Vector2i:
		return Vector2i(floor(v.x / cell_size), floor(v.y / cell_size))
	
	# 查询半径内是否已有点
	func has_near(p: Vector2, r: float) -> bool:
		var h      : Vector2i = _hash(p)
		var radius : int      = int(ceil(r / cell_size))
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var key := Vector2i(h.x + dx, h.y + dy)
				if data.has(key):
					for q in data[key]:
						if p.distance_to(q) < r:
							return true
		return false
	
	func add_point(p: Vector2) -> void:
		var h := _hash(p)
		if not data.has(h):
			data[h] = []
		data[h].append(p)

# ————————————————————————————————————————————————————————

func _ready() -> void:
	randomize()
	clearance = road_half_width + edge_falloff + EXTRA_MARGIN
	_generate_road_network()
	queue_redraw()  # 触发 _draw() 调试可视化
	
	# 如果你已有“挖高度图”的函数，可直接在这里调用：
	# _bake_into_heightmap(paths)
	
# —————————————————— 生成主函数 ———————————————————
func _generate_road_network() -> void:
	paths  = []                  # 重置
	var rng = RandomNumberGenerator.new(); rng.randomize()
	
	# 起终点：简单放两侧，你也可以传参进来
	var start := Vector2(5,  map_size.y * 0.5)
	var goal  := Vector2(map_size.x - 5, map_size.y * 0.5)
	
	var spatial := SpatialHash2D.new(clearance)
	
	# 主干 path
	var main_path : Array = [start]
	paths.append(main_path)
	spatial.add_point(start)
	
	# active_list 存正在生长的端点
	active_endpoints = [              # 用成员变量
		{
			"p": start,
			"dir": Vector2.RIGHT,
			"depth": 0,
			"path": main_path
		}
	]
	
	var iteration = 0
	while active_endpoints.size() > 0 and iteration < max_iter:
		iteration += 1
		var idx   = rng.randi_range(0, active_endpoints.size() - 1)
		var node  = active_endpoints[idx]
		
		if _grow_from_node(node, rng, spatial):
			# 仍活跃，留在 active 里
			pass
		else:
			# 死路，从 active 删除
			active_endpoints.remove_at(idx)
	
	# 把主干最后一个点连到 goal（尽量直连；失败会弯一点）
	_connect_to_goal(main_path, goal, spatial, rng)
	start_point = start
	goal_point  = goal
	
	print("Road generation done. Paths:", paths.size())
	for p in paths:
		print("  → path length:", p.size())
	
# ———————————————— 生长一个端点 ————————————————
func _grow_from_node(node: Dictionary, rng: RandomNumberGenerator, spatial: SpatialHash2D) -> bool:
	var p      : Vector2 = node["p"]
	var dir    : Vector2 = node["dir"]
	var depth  : int     = node["depth"]
	var path   : Array   = node["path"]
	
	var success := false
	for attempt in range(max_fail_per_node):
		var seg_len = rng.randf_range(seg_len_min, seg_len_max)
		
		# 50% 直线，50% 转弯
		var is_turn := rng.randf() < 0.5
		var new_dir := dir
		if is_turn:
			var ang  = deg_to_rad(rng.randf_range(min_turn_angle_deg, max_turn_angle_deg))
			if rng.randf() < 0.5:
				ang = -ang
			new_dir = dir.rotated(ang).normalized()
		
		var pts := _sample_segment(p, new_dir, seg_len)
		if not _inside_bounds(pts):
			continue
		if _hits_existing(pts, spatial):
			continue
		
		# 成功
		success = true
		for q in pts:
			spatial.add_point(q)
			path.append(q)
		
		# 更新当前端点信息
		node["p"]   = pts.back()
		node["dir"] = new_dir
		
		# —新增分支—
		if depth < branch_depth_max and rng.randf() < branch_prob:
			var b_ang = deg_to_rad(rng.randf_range(branch_angle_min, branch_angle_max))
			if rng.randf() < 0.5:
				b_ang = -b_ang
			var b_dir = new_dir.rotated(b_ang).normalized()
			var branch_path : Array = []
			paths.append(branch_path)
			active_endpoints.append({
				"p": pts.back(),
				"dir": b_dir,
				"depth": depth + 1,
				"path": branch_path
			})
		break
	
	return success

# ———————————————— 直连终点 —————————————————
func _connect_to_goal(main_path: Array, goal: Vector2,
		spatial: SpatialHash2D, rng: RandomNumberGenerator) -> void:
	var tail : Vector2 = main_path.back()
	var dir_to_goal   := (goal - tail).normalized()
	
	# 先尝试直接一段直线
	var pts := _sample_segment(tail, dir_to_goal, tail.distance_to(goal))
	if _inside_bounds(pts) and not _hits_existing(pts, spatial):
		for q in pts:
			spatial.add_point(q)
			main_path.append(q)
		main_path.append(goal)
		return
	
	# 直连失败 → 弯一点再尝试
	for i in range(8):
		var sign = 1 if rng.randf() < 0.5 else -1
		var ang  = deg_to_rad(rng.randf_range(20.0, 60.0)) * sign
		var detour_dir := dir_to_goal.rotated(ang).normalized()
		pts = _sample_segment(tail, detour_dir, seg_len_max)
		if _inside_bounds(pts) and not _hits_existing(pts, spatial):
			for q in pts:
				spatial.add_point(q)
				main_path.append(q)
			# 再次试直连
			_connect_to_goal(main_path, goal, spatial, rng)
			return
	# 如果还是失败就放弃，终点可能连不到

# ———————————————— 工具函数 —————————————————
func _sample_segment(start: Vector2, dir: Vector2, length: float) -> Array:
	var pts : Array = []
	var steps := int(ceil(length / debug_step))
	for i in range(2, steps + 1):
		pts.append(start + dir * debug_step * i)
	return pts

func _inside_bounds(pts: Array) -> bool:
	for p in pts:
		if p.x < 0 or p.x >= map_size.x or p.y < 0 or p.y >= map_size.y:
			return false
	return true

func _hits_existing(pts: Array, spatial: SpatialHash2D) -> bool:
	for p in pts:
		if spatial.has_near(p, clearance):
			return true
	return false

# ———————————————— Debug Draw —————————————————
func _draw() -> void:
	if not debug_draw:
		return
	for path in paths:
		for i in range(path.size() - 1):
			draw_line(path[i], path[i + 1], Color.SKY_BLUE, 1.0, true)
	draw_circle(start_point, 2.5, Color.LIGHT_GOLDENROD)
	draw_circle(goal_point,  2.5, Color.HOT_PINK)

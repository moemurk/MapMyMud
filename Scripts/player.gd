extends VehicleBody3D

@export var MAX_STEER = 0.8
@export var ENGINE_POWR = 300

@onready var camera_pivot = $CameraPivot
@onready var camera_3d = $CameraPivot/Camera3D
@onready var reverse_camera = $CameraPivot/ReverseCamera

var look_at_smooth

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	look_at_smooth = global_position

func _physics_process(delta):
	if Network.play_roll == Client.PlayRoll.Driver:
		var steering_input = Input.get_axis("right", "left")
		steering = move_toward(steering, steering_input * MAX_STEER, delta * 2.5)
		var engine_force_input = Input.get_axis("down", "up")
		engine_force = engine_force_input * ENGINE_POWR
		Network.car_move.rpc(position, rotation)
	
	camera_pivot.global_position = camera_pivot.global_position.lerp(global_position, delta * 20.0) #camera follows car
	camera_pivot.transform = camera_pivot.transform.interpolate_with(transform, delta * 5.0) #camera rotates
	look_at_smooth = look_at_smooth.lerp(global_position + linear_velocity, delta * 5.0)
	camera_3d.look_at(look_at_smooth)
	reverse_camera.look_at(look_at_smooth)
	_check_camera_swith()
	
	
func _check_camera_swith():
	if linear_velocity.length() > 1.0:
		if linear_velocity.dot(transform.basis.z) > -5.0:
			camera_3d.current = true
		else:
			reverse_camera.current = true

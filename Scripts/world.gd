extends Node3D

@onready var velocity_label = $CanvasLayer/Velocity_Label
@onready var nissan_gtr = $"Nissan GTR"


func _process(delta):
	if nissan_gtr and nissan_gtr is VehicleBody3D:
		var speed = nissan_gtr.linear_velocity.length() #speed in m/s
		velocity_label.text = "Speed: " + str(round(speed * 3.6 * 10) / 10) + "km/h"

func _ready() -> void:
	# to change car node name
	# and add it to Network states
	if nissan_gtr and nissan_gtr is VehicleBody3D:
		var driver_id = null
		if Network.play_roll == Client.PlayRoll.Driver:
			driver_id = multiplayer.get_unique_id()
		else:
			for team in Network.teams:
				team = team as Array[Client]
				if team[1]._network_id == multiplayer.get_unique_id():
					driver_id = (team[0] as Client)._network_id
		nissan_gtr.name = str(driver_id)
		Network.cars.append(nissan_gtr)

func abc():
	print("aaaaaaaaaaaaaaaaaa")

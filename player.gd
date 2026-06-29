extends Area2D

@export var laser_scene: PackedScene = preload("res://laser.tscn")
@export var smooth_speed: float = 25.0 # High value for responsive yet smooth motion

@onready var shoot_timer: Timer = $ShootTimer
@onready var laser_spawn: Marker2D = $LaserSpawn

var viewport_width: float = 720.0
var half_width: float = 30.0

func _ready() -> void:
	viewport_width = get_viewport_rect().size.x
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	# Position player near bottom center
	var viewport_size = get_viewport_rect().size
	position = Vector2(viewport_size.x / 2.0, viewport_size.y - 120.0)

func _process(delta: float) -> void:
	# Check if user is touching/dragging (mouse click is mapped to touch)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var target_x = get_global_mouse_position().x
		target_x = clamp(target_x, half_width, viewport_width - half_width)
		# Smoothly interpolate X coordinate to target
		position.x = lerp(position.x, target_x, smooth_speed * delta)

func _on_shoot_timer_timeout() -> void:
	shoot_laser()

func shoot_laser() -> void:
	if laser_scene:
		var laser = laser_scene.instantiate()
		laser.global_position = laser_spawn.global_position
		# Spawn laser under the parent node (e.g. Main) so it moves independently
		get_parent().add_child(laser)

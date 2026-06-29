extends Area2D

@export var laser_scene: PackedScene = preload("res://laser.tscn")

@onready var shoot_timer: Timer = $ShootTimer
@onready var laser_spawn: Marker2D = $LaserSpawn

# Gameplay stats
var lives: int = 3
var shield: int = 5
var max_shield: int = 5
var boost: float = 4.0
var max_boost: float = 4.0

# Sensitivity control
var sensitivity: float = 1.6 # Can be adjusted (1.0 to 3.0) via Settings

# State variables
var is_invulnerable: bool = false
var invun_timer: float = 0.0
var flash_timer: float = 0.0
var shield_recharge_timer: float = 0.0

var is_boosting: bool = false
var is_boost_button_pressed: bool = false # Managed by Main UI controls

var viewport_width: float = 720.0
var half_width: float = 30.0

func _ready() -> void:
	viewport_width = get_viewport_rect().size.x
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	reset_player_stats()

func reset_player_stats() -> void:
	lives = 3
	shield = max_shield
	boost = max_boost
	is_invulnerable = false
	is_boosting = false
	is_boost_button_pressed = false
	visible = true
	set_process(true)
	
	# Safely re-enable monitoring properties
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
	var viewport_size = get_viewport_rect().size
	position = Vector2(viewport_size.x / 2.0, viewport_size.y - 120.0)
	
	call_deferred("update_hud")

func _process(delta: float) -> void:
	# 1. Movement: Follow mouse/touch X drag
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var target_x = get_global_mouse_position().x
		target_x = clamp(target_x, half_width, viewport_width - half_width)
		# Smooth speed scales with sensitivity setting
		var actual_speed = sensitivity * 15.0
		position.x = lerp(position.x, target_x, actual_speed * delta)

	# 2. Invulnerability Flash Handler
	if is_invulnerable:
		invun_timer -= delta
		flash_timer += delta
		if flash_timer >= 0.08:
			flash_timer = 0.0
			visible = not visible
		if invun_timer <= 0.0:
			is_invulnerable = false
			visible = true
			set_deferred("monitoring", true)
			set_deferred("monitorable", true)

	# 3. Boost Overdrive Firing Speed Handler
	var want_boost = Input.is_key_pressed(KEY_SPACE) or is_boost_button_pressed
	if want_boost and boost > 0.0:
		if not is_boosting:
			is_boosting = true
			shoot_timer.wait_time = 0.1 # Double firing rate
			shoot_timer.start()
		boost -= delta * 1.5 # Drains in ~2.7 seconds
		if boost < 0.0:
			boost = 0.0
	else:
		if is_boosting:
			is_boosting = false
			shoot_timer.wait_time = 0.2 # Normal firing rate
			shoot_timer.start()
		if boost < max_boost:
			boost += delta * 0.5 # Recharges in 8 seconds
			if boost > max_boost:
				boost = max_boost

	# 4. Shield Recharge Handler (slowly recharge if not hit recently)
	if shield < max_shield and not is_invulnerable:
		shield_recharge_timer += delta
		if shield_recharge_timer >= 12.0:
			shield += 1
			shield_recharge_timer = 0.0
			update_hud()
	else:
		if shield >= max_shield:
			shield_recharge_timer = 0.0

	# 5. Continuous HUD Sync during active status changes
	if want_boost or boost < max_boost or is_invulnerable:
		update_hud()

func take_damage() -> void:
	if is_invulnerable:
		return
	
	# Trigger screen shake or hit visual in main if possible
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("spawn_player_hit_effect"):
		main_scene.spawn_player_hit_effect(global_position)
	
	if shield > 0:
		shield -= 1
		make_invulnerable(1.0) # Brief invulnerability
	else:
		lives -= 1
		make_invulnerable(1.8) # Longer invulnerability for life loss
	
	update_hud()
	
	if lives <= 0:
		if main_scene and main_scene.has_method("trigger_game_over"):
			main_scene.trigger_game_over()

func make_invulnerable(duration: float) -> void:
	is_invulnerable = true
	invun_timer = duration
	flash_timer = 0.0
	# Temporarily disable physical collisions safely
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func update_hud() -> void:
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("update_player_stats"):
		main_scene.update_player_stats(lives, shield, boost)

func _on_shoot_timer_timeout() -> void:
	shoot_laser()

func shoot_laser() -> void:
	if laser_scene:
		var laser = laser_scene.instantiate()
		laser.global_position = laser_spawn.global_position
		get_parent().add_child(laser)

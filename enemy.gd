extends Area2D

@export var speed: float = 200.0
@export var enemy_type: int = 0 # 0: Normal, 1: Fast, 2: Heavy, 3: Kamikaze, 4: Fighter, 5: Boss, 6: Stealth, 7: Mine, 8: Drone
@export var explosion_scene: PackedScene = preload("res://explosion.tscn")
@export var bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")

var health: int = 1
var max_health: int = 1
var velocity: Vector2 = Vector2.ZERO

# Boss profiles configurations
var boss_profile: int = 1 # 1: Vanguard (Stg 5), 2: Goliath (Stg 10), 3: Carrier (Stg 15), 4: Dreadnought (Stg 20)
var is_boss_shielded: bool = false

# Movement & Action States
var time_elapsed: float = 0.0
var spawn_x: float = 0.0
var charge_timer: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO

# Stealth & Drone parameters
var stealth_fade_timer: float = 0.0
var stealth_is_fading_in: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	
	spawn_x = position.x
	
	# Determine Boss Profile based on Stage Number
	if enemy_type == 5:
		var main_scene = get_tree().current_scene
		var stage = main_scene.current_level if main_scene and "current_level" in main_scene else 5
		if stage % 20 == 5: boss_profile = 1
		elif stage % 20 == 10: boss_profile = 2
		elif stage % 20 == 15: boss_profile = 3
		elif stage % 20 == 0: boss_profile = 4
		else: boss_profile = 1 # Fallback
	
	# Configure polygon vertices, colors, scale, and stats
	setup_type_properties()

func setup_type_properties() -> void:
	match enemy_type:
		0: # TYPE_NORMAL
			max_health = 1
			health = 1
			$Polygon2D.scale = Vector2(1, 1)
			$Outline.scale = Vector2(1, 1)
			$Outline.default_color = Color(1.0, 0.5, 0.2, 1.0) # Orange
			_apply_glow(Color(1.0, 0.5, 0.2, 0.12), Vector2(1, 1))
			_apply_cracks(Color(1.0, 0.5, 0.2, 0.35), Vector2(1, 1))
		1: # TYPE_FAST
			max_health = 1
			health = 1
			$Polygon2D.scale = Vector2(0.6, 0.6)
			$Outline.scale = Vector2(0.6, 0.6)
			$Outline.default_color = Color(1.0, 0.1, 0.3, 1.0) # Hot Red
			$CollisionShape2D.scale = Vector2(0.6, 0.6)
			_apply_glow(Color(1.0, 0.1, 0.3, 0.15), Vector2(0.6, 0.6))
			_apply_cracks(Color(1.0, 0.1, 0.3, 0.4), Vector2(0.6, 0.6))
		2: # TYPE_HEAVY
			max_health = 3
			health = 3
			$Polygon2D.scale = Vector2(1.8, 1.8)
			$Outline.scale = Vector2(1.8, 1.8)
			$Outline.default_color = Color(0.66, 0.23, 1.0, 1.0) # Purple
			$CollisionShape2D.scale = Vector2(1.8, 1.8)
			$Polygon2D.color = Color(0.12, 0.08, 0.18, 1.0)
			_apply_glow(Color(0.66, 0.23, 1.0, 0.15), Vector2(1.8, 1.8))
			_apply_cracks(Color(0.66, 0.23, 1.0, 0.3), Vector2(1.8, 1.8))
		3: # TYPE_KAMIKAZE (Shooting Star)
			max_health = 1
			health = 1
			$Polygon2D.scale = Vector2(0.7, 1.3)
			$Outline.scale = Vector2(0.7, 1.3)
			$Outline.default_color = Color(0.0, 1.0, 0.8, 1.0) # Cyan
			$CollisionShape2D.scale = Vector2(0.8, 1.2)
			_apply_glow(Color(0.0, 1.0, 0.8, 0.15), Vector2(0.7, 1.3))
			_apply_cracks(Color(0.0, 1.0, 0.8, 0.3), Vector2(0.7, 1.3))
			charge_timer = 0.5
			var player_node = get_tree().current_scene.get_node_or_null("Player")
			var target_x = player_node.global_position.x if player_node else spawn_x
			charge_direction = Vector2(target_x - position.x, 1000.0).normalized()
		4: # TYPE_FIGHTER
			max_health = 2
			health = 2
			$Polygon2D.scale = Vector2(1.2, 1.2)
			$Outline.scale = Vector2(1.2, 1.2)
			$Outline.default_color = Color(1.0, 0.0, 0.6, 1.0) # Magenta
			$CollisionShape2D.scale = Vector2(1.2, 1.2)
			$Polygon2D.polygon = PackedVector2Array([Vector2(0, 20), Vector2(-15, -15), Vector2(-5, -5), Vector2(5, -5), Vector2(15, -15)])
			$Outline.points = PackedVector2Array([Vector2(0, 20), Vector2(-15, -15), Vector2(-5, -5), Vector2(5, -5), Vector2(15, -15), Vector2(0, 20)])
			_apply_glow_custom(Color(1.0, 0.0, 0.6, 0.15), $Outline.points, Vector2(1.2, 1.2))
			_hide_cracks()
			
			var t = Timer.new()
			t.wait_time = 1.2
			t.autostart = true
			t.timeout.connect(fighter_shoot)
			add_child(t)
		6: # TYPE_STEALTH (Translucent, flashes in to fire 3-way)
			max_health = 2
			health = 2
			$Polygon2D.scale = Vector2(1.2, 1.2)
			$Outline.scale = Vector2(1.2, 1.2)
			$Outline.default_color = Color(0.4, 0.6, 0.8, 0.4) # Faded Gray-blue
			$CollisionShape2D.scale = Vector2(1.2, 1.2)
			modulate.a = 0.25
			$Polygon2D.polygon = PackedVector2Array([Vector2(0, 15), Vector2(-22, -10), Vector2(-8, -2), Vector2(8, -2), Vector2(22, -10)])
			$Outline.points = PackedVector2Array([Vector2(0, 15), Vector2(-22, -10), Vector2(-8, -2), Vector2(8, -2), Vector2(22, -10), Vector2(0, 15)])
			_apply_glow_custom(Color(0.4, 0.6, 0.8, 0.1), $Outline.points, Vector2(1.2, 1.2))
			_hide_cracks()
		7: # TYPE_MINE (Stationary/slow drift, detonates radial bullets when shot)
			max_health = 1
			health = 1
			$Polygon2D.scale = Vector2(1.1, 1.1)
			$Outline.scale = Vector2(1.1, 1.1)
			$Outline.default_color = Color(1.0, 0.1, 0.1, 1.0) # Danger Red
			$CollisionShape2D.scale = Vector2(1.1, 1.1)
			$Polygon2D.polygon = PackedVector2Array([Vector2(0, -15), Vector2(5, -5), Vector2(15, 0), Vector2(5, 5), Vector2(0, 15), Vector2(-5, 5), Vector2(-15, 0), Vector2(-5, -5)])
			$Outline.points = PackedVector2Array([Vector2(0, -15), Vector2(5, -5), Vector2(15, 0), Vector2(5, 5), Vector2(0, 15), Vector2(-5, 5), Vector2(-15, 0), Vector2(-5, -5), Vector2(0, -15)])
			_apply_glow_custom(Color(1.0, 0.1, 0.1, 0.2), $Outline.points, Vector2(1.1, 1.1))
			_hide_cracks()
		8: # TYPE_DRONE (Green diamond, locks on player's X, fires rapid green beams)
			max_health = 2
			health = 2
			$Polygon2D.scale = Vector2(1.0, 1.0)
			$Outline.scale = Vector2(1.0, 1.0)
			$Outline.default_color = Color(0.1, 1.0, 0.2, 1.0) # Lime Green
			$CollisionShape2D.scale = Vector2(1.0, 1.0)
			$Polygon2D.polygon = PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)])
			$Outline.points = PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0), Vector2(0, -12)])
			_apply_glow_custom(Color(0.1, 1.0, 0.2, 0.15), $Outline.points, Vector2(1.0, 1.0))
			_hide_cracks()
			
			var t = Timer.new()
			t.wait_time = 0.65
			t.autostart = true
			t.timeout.connect(drone_shoot)
			add_child(t)
		5: # TYPE_BOSS (Stage-based profiles)
			_hide_cracks()
			setup_boss_profile()

func _apply_glow(glow_color: Color, s: Vector2) -> void:
	var glow = get_node_or_null("Glow")
	if glow:
		glow.default_color = glow_color
		glow.scale = s

func _apply_cracks(crack_color: Color, s: Vector2) -> void:
	var c1 = get_node_or_null("SurfaceCrack1")
	var c2 = get_node_or_null("SurfaceCrack2")
	if c1:
		c1.default_color = crack_color
		c1.scale = s
		c1.visible = true
	if c2:
		c2.default_color = Color(crack_color.r, crack_color.g, crack_color.b, crack_color.a * 0.7)
		c2.scale = s
		c2.visible = true

func _apply_glow_custom(glow_color: Color, pts: PackedVector2Array, s: Vector2) -> void:
	var glow = get_node_or_null("Glow")
	if glow:
		glow.points = pts
		glow.default_color = glow_color
		glow.scale = s

func _hide_cracks() -> void:
	var c1 = get_node_or_null("SurfaceCrack1")
	var c2 = get_node_or_null("SurfaceCrack2")
	if c1: c1.visible = false
	if c2: c2.visible = false

func setup_boss_profile() -> void:
	var main_scene = get_tree().current_scene
	
	match boss_profile:
		1: # VANGUARD OUTPOST
			max_health = 20 + int(main_scene.current_level / 5.0 - 1.0) * 10 if main_scene else 20
			health = max_health
			$Polygon2D.scale = Vector2(2.5, 2.5)
			$Outline.scale = Vector2(2.5, 2.5)
			$Outline.default_color = Color(1.0, 0.0, 0.47, 1.0) # Hot Pink
			$CollisionShape2D.scale = Vector2(2.5, 2.5)
			$Polygon2D.polygon = PackedVector2Array([Vector2(0, -30), Vector2(30, -12), Vector2(30, 12), Vector2(0, 30), Vector2(-30, 12), Vector2(-30, -12)])
			$Outline.points = PackedVector2Array([Vector2(0, -30), Vector2(30, -12), Vector2(30, 12), Vector2(0, 30), Vector2(-30, 12), Vector2(-30, -12), Vector2(0, -30)])
			$Polygon2D.color = Color(0.08, 0.04, 0.15, 1.0)
			_apply_glow_custom(Color(1.0, 0.0, 0.47, 0.18), $Outline.points, Vector2(2.5, 2.5))
			
			var t_shoot = Timer.new()
			t_shoot.wait_time = 0.8
			t_shoot.autostart = true
			t_shoot.timeout.connect(boss_shoot)
			add_child(t_shoot)
			
			var t_meteor = Timer.new()
			t_meteor.wait_time = 2.5
			t_meteor.autostart = true
			t_meteor.timeout.connect(boss_spawn_meteor)
			add_child(t_meteor)
		2: # GOLIATH CRUISER
			max_health = 35 + int(main_scene.current_level / 5.0 - 2.0) * 15 if main_scene else 35
			health = max_health
			$Polygon2D.scale = Vector2(2.5, 2.5)
			$Outline.scale = Vector2(2.5, 2.5)
			$Outline.default_color = Color(1.0, 0.8, 0.0, 1.0) # Gold
			$CollisionShape2D.scale = Vector2(2.5, 2.5)
			$Polygon2D.polygon = PackedVector2Array([Vector2(0, 30), Vector2(-35, -20), Vector2(0, -8), Vector2(35, -20)])
			$Outline.points = PackedVector2Array([Vector2(0, 30), Vector2(-35, -20), Vector2(0, -8), Vector2(35, -20), Vector2(0, 30)])
			$Polygon2D.color = Color(0.15, 0.1, 0.02, 1.0)
			_apply_glow_custom(Color(1.0, 0.8, 0.0, 0.18), $Outline.points, Vector2(2.5, 2.5))
			
			var t_goliath = Timer.new()
			t_goliath.wait_time = 1.0
			t_goliath.autostart = true
			t_goliath.timeout.connect(goliath_shoot)
			add_child(t_goliath)
			
			var t_shield = Timer.new()
			t_shield.wait_time = 4.0
			t_shield.autostart = true
			t_shield.timeout.connect(toggle_goliath_shield)
			add_child(t_shield)
		3: # CARRIER LEVIATHAN
			max_health = 50 + int(main_scene.current_level / 5.0 - 3.0) * 20 if main_scene else 50
			health = max_health
			$Polygon2D.scale = Vector2(2.5, 2.5)
			$Outline.scale = Vector2(2.5, 2.5)
			$Outline.default_color = Color(0.66, 0.23, 1.0, 1.0) # Violet
			$CollisionShape2D.scale = Vector2(2.5, 2.5)
			$Polygon2D.polygon = PackedVector2Array([Vector2(-45, -15), Vector2(-45, 15), Vector2(-15, 22), Vector2(15, 22), Vector2(45, 15), Vector2(45, -15), Vector2(0, -25)])
			$Outline.points = PackedVector2Array([Vector2(-45, -15), Vector2(-45, 15), Vector2(-15, 22), Vector2(15, 22), Vector2(45, 15), Vector2(45, -15), Vector2(0, -25), Vector2(-45, -15)])
			$Polygon2D.color = Color(0.05, 0.02, 0.12, 1.0)
			_apply_glow_custom(Color(0.66, 0.23, 1.0, 0.18), $Outline.points, Vector2(2.5, 2.5))
			
			var t_fighter = Timer.new()
			t_fighter.wait_time = 4.2
			t_fighter.autostart = true
			t_fighter.timeout.connect(carrier_spawn_fighter)
			add_child(t_fighter)
			
			var t_homing = Timer.new()
			t_homing.wait_time = 1.5
			t_homing.autostart = true
			t_homing.timeout.connect(carrier_shoot_homing)
			add_child(t_homing)
		4: # HYPERION DREADNOUGHT
			max_health = 75 + int(main_scene.current_level / 5.0 - 4.0) * 25 if main_scene else 75
			health = max_health
			$Polygon2D.scale = Vector2(2.6, 2.6)
			$Outline.scale = Vector2(2.6, 2.6)
			$Outline.default_color = Color(1.0, 0.2, 0.1, 1.0) # Crimson Red
			$CollisionShape2D.scale = Vector2(2.6, 2.6)
			$Polygon2D.polygon = PackedVector2Array([Vector2(-35, -25), Vector2(-15, 0), Vector2(15, 0), Vector2(35, -25), Vector2(25, 25), Vector2(8, 12), Vector2(0, 30), Vector2(-8, 12), Vector2(-25, 25)])
			$Outline.points = PackedVector2Array([Vector2(-35, -25), Vector2(-15, 0), Vector2(15, 0), Vector2(35, -25), Vector2(25, 25), Vector2(8, 12), Vector2(0, 30), Vector2(-8, 12), Vector2(-25, 25), Vector2(-35, -25)])
			$Polygon2D.color = Color(0.16, 0.02, 0.02, 1.0)
			_apply_glow_custom(Color(1.0, 0.2, 0.1, 0.2), $Outline.points, Vector2(2.6, 2.6))
			
			var t_beam = Timer.new()
			t_beam.wait_time = 4.6
			t_beam.autostart = true
			t_beam.timeout.connect(dreadnought_shoot_beam)
			add_child(t_beam)
			
			var t_radial = Timer.new()
			t_radial.wait_time = 2.4
			t_radial.autostart = true
			t_radial.timeout.connect(dreadnought_radial_burst)
			add_child(t_radial)

	# Trigger health bar synchronization with boss name
	var boss_display_name = "UNKNOWN"
	match boss_profile:
		1: boss_display_name = "VANGUARD OUTPOST"
		2: boss_display_name = "GOLIATH CRUISER"
		3: boss_display_name = "CARRIER LEVIATHAN"
		4: boss_display_name = "HYPERION DREADNOUGHT"
	if main_scene and main_scene.has_method("show_boss_health_bar"):
		main_scene.show_boss_health_bar(max_health, boss_display_name)

func _physics_process(delta: float) -> void:
	time_elapsed += delta
	
	match enemy_type:
		3: # Kamikaze
			if charge_timer > 0.0:
				charge_timer -= delta
				modulate = Color(4.0, 4.0, 4.0, 1.0) if Engine.get_frames_drawn() % 4 < 2 else Color.WHITE
			else:
				modulate = Color.WHITE
				position += charge_direction * speed * 2.2 * delta
		4: # Fighter (Zig-zag)
			position.y += speed * delta
			position.x = spawn_x + sin(time_elapsed * 4.0) * 80.0
		6: # Stealth Bomber (Fade opacity in/out)
			position.y += speed * delta
			stealth_fade_timer += delta
			if stealth_fade_timer >= 1.6:
				stealth_fade_timer = 0.0
				stealth_shoot()
			
			# Modulate opacity smoothly: peaks at shooting moment
			var weight = sin(stealth_fade_timer * (PI / 1.6))
			modulate.a = lerp(0.2, 1.0, weight)
		7: # Gravity Mine (Slow drift)
			position.y += speed * delta
		8: # Hunter Drone (Tracks player X, slides down)
			position.y += speed * delta
			var player_node = get_tree().current_scene.get_node_or_null("Player")
			if player_node:
				var player_x = player_node.global_position.x
				position.x = lerp(position.x, player_x, 1.5 * delta)
		5: # Boss Movement Control
			if position.y < 180.0:
				position.y += speed * delta
			else:
				position.y = 180.0
				# Goliath swings faster, Leviathan slower, Dreadnought swings in wider margins
				var swing_speed = 1.2
				var swing_width = 200.0
				if boss_profile == 2: swing_speed = 1.6
				elif boss_profile == 3: swing_speed = 0.8
				elif boss_profile == 4: swing_width = 220.0
				position.x = 360.0 + sin(time_elapsed * swing_speed) * swing_width
		_: # Normal, Fast, Heavy
			if velocity != Vector2.ZERO:
				position += velocity * delta
			else:
				position.y += speed * delta

func fighter_shoot() -> void:
	if bullet_scene and get_tree().paused == false:
		var b = bullet_scene.instantiate()
		b.global_position = global_position + Vector2(0, 20)
		b.speed = 500.0
		get_parent().add_child(b)

func drone_shoot() -> void:
	if bullet_scene and get_tree().paused == false:
		var b = bullet_scene.instantiate()
		b.global_position = global_position + Vector2(0, 15)
		b.speed = 520.0
		var line = b.get_node_or_null("Line2D")
		if line:
			line.default_color = Color(0.1, 1.0, 0.2, 1.0) # Green plasma
		get_parent().add_child(b)

func stealth_shoot() -> void:
	if bullet_scene and get_tree().paused == false:
		# 3-way spread stream
		for i in range(3):
			var b = bullet_scene.instantiate()
			b.global_position = global_position + Vector2(0, 15)
			var angle = -0.15 if i == 0 else (0.15 if i == 2 else 0.0)
			b.velocity = Vector2(angle * 500.0, 500.0)
			var line = b.get_node_or_null("Line2D")
			if line:
				line.default_color = Color(0.4, 0.6, 0.8, 1.0) # Gray-blue bullet
			get_parent().add_child(b)

# Boss-specific firing profiles
func boss_shoot() -> void:
	if bullet_scene and get_tree().paused == false:
		for i in range(2):
			var b = bullet_scene.instantiate()
			b.global_position = global_position + Vector2(-40 if i == 0 else 40, 30)
			var side_dir = -80.0 if i == 0 else 80.0
			b.velocity = Vector2(side_dir, 480.0)
			get_parent().add_child(b)

func boss_spawn_meteor() -> void:
	if get_parent() and get_tree().paused == false:
		var meteor = load("res://enemy.tscn").instantiate()
		meteor.enemy_type = 1 # TYPE_FAST
		meteor.position = global_position + Vector2(randf_range(-80.0, 80.0), 30)
		meteor.speed = randf_range(300.0, 450.0)
		get_parent().add_child(meteor)

func goliath_shoot() -> void:
	if bullet_scene and get_tree().paused == false:
		for i in range(3):
			var b = bullet_scene.instantiate()
			b.global_position = global_position + Vector2(0, 30)
			var side_x = -150.0 if i == 0 else (150.0 if i == 2 else 0.0)
			b.velocity = Vector2(side_x, 480.0)
			var line = b.get_node_or_null("Line2D")
			if line:
				line.default_color = Color(1.0, 0.8, 0.0, 1.0) # Yellow bullets
			get_parent().add_child(b)

func toggle_goliath_shield() -> void:
	if get_tree().paused == false:
		is_boss_shielded = !is_boss_shielded
		if is_boss_shielded:
			$Outline.default_color = Color(0.0, 0.94, 1.0, 1.0) # Glowing Cyan shield
			$Outline.width = 6.0
			modulate = Color(2.0, 2.0, 2.0, 1.0)
			get_tree().create_timer(0.12).timeout.connect(func(): modulate = Color.WHITE)
			
			# Automatically drop shield after 1.8 seconds
			get_tree().create_timer(1.8).timeout.connect(func():
				if is_instance_valid(self):
					is_boss_shielded = false
					$Outline.default_color = Color(1.0, 0.8, 0.0, 1.0)
					$Outline.width = 2.0
			)

func carrier_spawn_fighter() -> void:
	if get_parent() and get_tree().paused == false:
		var f = load("res://enemy.tscn").instantiate()
		f.enemy_type = 4 # TYPE_FIGHTER
		f.position = global_position + Vector2(randf_range(-100.0, 100.0), 30)
		f.speed = randf_range(160.0, 220.0)
		get_parent().add_child(f)

func carrier_shoot_homing() -> void:
	if bullet_scene and get_tree().paused == false:
		for i in range(2):
			var b = bullet_scene.instantiate()
			b.global_position = global_position + Vector2(-60 if i == 0 else 60, 20)
			b.is_homing = true
			b.speed = 380.0
			var line = b.get_node_or_null("Line2D")
			if line:
				line.default_color = Color(0.66, 0.23, 1.0, 1.0) # Purple lasers
			get_parent().add_child(b)

func dreadnought_shoot_beam() -> void:
	if get_parent() and get_tree().paused == false:
		var beam_scene = load("res://boss_beam.tscn")
		if beam_scene:
			var b = beam_scene.instantiate()
			b.position = Vector2(position.x, position.y + 40.0)
			get_parent().add_child(b)

func dreadnought_radial_burst() -> void:
	if bullet_scene and get_tree().paused == false:
		for i in range(8):
			var angle = i * (PI / 4.0)
			var b = bullet_scene.instantiate()
			b.global_position = global_position + Vector2(0, 30)
			b.velocity = Vector2(cos(angle) * 400.0, sin(angle) * 400.0)
			var line = b.get_node_or_null("Line2D")
			if line:
				line.default_color = Color(1.0, 0.4, 0.0, 1.0) # Orange laser points
			get_parent().add_child(b)

func _on_screen_exited() -> void:
	# Keep bosses active until defeated
	if enemy_type != 5:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		# Shield reflect block check
		if enemy_type == 5 and is_boss_shielded:
			area.call_deferred("queue_free")
			modulate = Color(0.0, 3.0, 3.0, 1.0)
			get_tree().create_timer(0.08).timeout.connect(func(): modulate = Color.WHITE)
			return
			
		area.call_deferred("queue_free")
		
		# Decrement health
		health -= 1
		
		# Impact white flashing
		modulate = Color(3.0, 3.0, 3.0, 1.0)
		get_tree().create_timer(0.08).timeout.connect(func(): modulate = Color.WHITE)
		
		# Sync Boss HP
		if enemy_type == 5:
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("update_boss_health"):
				main_scene.update_boss_health(health, max_health)
				
		if health <= 0:
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("add_score"):
				var pts = 10
				match enemy_type:
					1: pts = 15
					2: pts = 30
					3: pts = 20
					4: pts = 25
					6: pts = 35 # Stealth Bomber
					7: pts = 20 # Mine
					8: pts = 30 # Drone
					5:
						# Scaled Boss Scores
						pts = 100 * boss_profile
				main_scene.add_score(pts)
			
			# Explosions particle burst
			if explosion_scene:
				var explosion = explosion_scene.instantiate()
				explosion.global_position = global_position
				if enemy_type == 5:
					explosion.scale = Vector2(2.8, 2.8)
					# Spawn secondary explosions for visual feedback
					for offset in [Vector2(-30, -30), Vector2(30, 30), Vector2(-30, 30), Vector2(30, -30)]:
						var ex = explosion_scene.instantiate()
						ex.global_position = global_position + offset
						ex.scale = Vector2(1.5, 1.5)
						get_parent().call_deferred("add_child", ex)
				elif enemy_type == 2:
					explosion.scale = Vector2(1.8, 1.8)
				elif enemy_type == 1:
					explosion.scale = Vector2(0.7, 0.7)
				get_parent().add_child(explosion)
			
			# Fragments split for Heavy
			if enemy_type == 2:
				spawn_fragments()
				
			# Detonation for Mines
			if enemy_type == 7:
				trigger_mine_explosion()
			
			# Notify Boss dead
			if enemy_type == 5:
				if main_scene and main_scene.has_method("on_boss_defeated"):
					main_scene.on_boss_defeated()
					
			call_deferred("queue_free")
			
	elif area.is_in_group("player"):
		if enemy_type == 5 and is_boss_shielded:
			pass
		if area.has_method("take_damage"):
			area.take_damage()
		call_deferred("queue_free")

func spawn_fragments() -> void:
	for i in range(2):
		var frag = load("res://enemy.tscn").instantiate()
		frag.enemy_type = 0 # TYPE_NORMAL
		frag.position = position
		var side_dir = -1.0 if i == 0 else 1.0
		frag.velocity = Vector2(side_dir * 120.0, speed * 1.1)
		get_parent().call_deferred("add_child", frag)

func trigger_mine_explosion() -> void:
	if bullet_scene and get_parent():
		# Spawn 8 bullets outward radially
		for i in range(8):
			var angle = i * (PI / 4.0)
			var b = bullet_scene.instantiate()
			b.global_position = global_position
			b.velocity = Vector2(cos(angle) * 350.0, sin(angle) * 350.0)
			var line = b.get_node_or_null("Line2D")
			if line:
				line.default_color = Color(1.0, 0.1, 0.1, 1.0) # Red mine fragments
			get_parent().call_deferred("add_child", b)

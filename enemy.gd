extends Area2D

@export var speed: float = 200.0
@export var enemy_type: int = 0 # 0: Normal, 1: Fast, 2: Heavy
@export var explosion_scene: PackedScene = preload("res://explosion.tscn")

var health: int = 1
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Connect collision and screen exit signals
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	
	# Configure asteroid scaling, health, and colors dynamically based on type
	match enemy_type:
		0: # TYPE_NORMAL
			health = 1
			$Polygon2D.scale = Vector2(1, 1)
			$Outline.scale = Vector2(1, 1)
			$Outline.default_color = Color(1.0, 0.5, 0.2, 1.0) # Orange Outline
		1: # TYPE_FAST (Small, rapid)
			health = 1
			$Polygon2D.scale = Vector2(0.6, 0.6)
			$Outline.scale = Vector2(0.6, 0.6)
			$Outline.default_color = Color(1.0, 0.1, 0.3, 1.0) # Hot Red Outline
			$CollisionShape2D.scale = Vector2(0.6, 0.6)
		2: # TYPE_HEAVY (Large, tough boss asteroid)
			health = 3
			$Polygon2D.scale = Vector2(1.8, 1.8)
			$Outline.scale = Vector2(1.8, 1.8)
			$Outline.default_color = Color(0.66, 0.23, 1.0, 1.0) # Purple Outline
			$CollisionShape2D.scale = Vector2(1.8, 1.8)
			# Tint body dark violet to feel heavy
			$Polygon2D.color = Color(0.12, 0.08, 0.18, 1.0)

func _physics_process(delta: float) -> void:
	# Move using custom velocity vector if set (for fragments), otherwise standard fall down
	if velocity != Vector2.ZERO:
		position += velocity * delta
	else:
		position.y += speed * delta

func _on_screen_exited() -> void:
	# Clean up offscreen asteroid
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		# Destroy laser projectile
		area.call_deferred("queue_free")
		
		# Decrement health
		health -= 1
		
		# Neon hit flash indicator (super-modulate to bright white)
		modulate = Color(3.0, 3.0, 3.0, 1.0)
		get_tree().create_timer(0.08).timeout.connect(func(): modulate = Color.WHITE)
		
		if health <= 0:
			# Notify main scene to add score
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("add_score"):
				# Heavy gives 30, fast gives 15, normal gives 10
				var pts = 10
				if enemy_type == 1: pts = 15
				elif enemy_type == 2: pts = 30
				main_scene.add_score(pts)
			
			# Instantiate explosion particles
			if explosion_scene:
				var explosion = explosion_scene.instantiate()
				explosion.global_position = global_position
				# Scale explosion size with asteroid type
				if enemy_type == 2:
					explosion.scale = Vector2(1.8, 1.8)
				elif enemy_type == 1:
					explosion.scale = Vector2(0.7, 0.7)
				get_parent().add_child(explosion)
			
			# Splitting logic for heavy asteroids
			if enemy_type == 2:
				spawn_fragments()
				
			call_deferred("queue_free")
			
	elif area.is_in_group("player"):
		# Notify player node to process damage
		if area.has_method("take_damage"):
			area.take_damage()
		call_deferred("queue_free")

func spawn_fragments() -> void:
	# Spawn 2 standard asteroids that scatter left and right
	for i in range(2):
		var frag = load("res://enemy.tscn").instantiate()
		frag.enemy_type = 0 # TYPE_NORMAL
		frag.position = position
		
		# Fragments fly slightly faster and angle left/right
		var side_dir = -1.0 if i == 0 else 1.0
		frag.velocity = Vector2(side_dir * 120.0, speed * 1.1)
		
		# Give a slight delay before adding to prevent immediate double collisions
		get_parent().call_deferred("add_child", frag)

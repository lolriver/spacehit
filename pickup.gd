extends Area2D

enum PickupType { SHIELD, HEART }

@export var pickup_type: int = PickupType.SHIELD
var speed: float = 120.0
var time_elapsed: float = 0.0

func _ready() -> void:
	setup_visual()
	area_entered.connect(_on_area_entered)

func setup_visual() -> void:
	var poly = $Polygon2D
	var outline = $Outline
	var glow = $Glow
	
	match pickup_type:
		PickupType.SHIELD:
			# Shield icon shape (hexagon)
			var pts = PackedVector2Array([
				Vector2(0, -14), Vector2(12, -7), Vector2(12, 7),
				Vector2(0, 14), Vector2(-12, 7), Vector2(-12, -7)
			])
			poly.polygon = pts
			poly.color = Color(0.0, 0.2, 0.25, 0.7)
			var closed_pts = pts.duplicate()
			closed_pts.append(pts[0])
			outline.points = closed_pts
			outline.default_color = Color(0.0, 0.94, 1.0, 1.0)
			glow.points = closed_pts
			glow.default_color = Color(0.0, 0.94, 1.0, 0.15)
			
			# Inner shield cross
			var cross = Line2D.new()
			cross.points = PackedVector2Array([Vector2(0, -8), Vector2(0, 8)])
			cross.width = 2.0
			cross.default_color = Color(0.0, 0.94, 1.0, 0.5)
			add_child(cross)
			var cross2 = Line2D.new()
			cross2.points = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0)])
			cross2.width = 2.0
			cross2.default_color = Color(0.0, 0.94, 1.0, 0.5)
			add_child(cross2)
			
		PickupType.HEART:
			# Heart shape approximation
			var pts = PackedVector2Array([
				Vector2(0, 12), Vector2(-12, 0), Vector2(-10, -8),
				Vector2(-5, -12), Vector2(0, -8),
				Vector2(5, -12), Vector2(10, -8), Vector2(12, 0)
			])
			poly.polygon = pts
			poly.color = Color(0.25, 0.02, 0.08, 0.7)
			var closed_pts = pts.duplicate()
			closed_pts.append(pts[0])
			outline.points = closed_pts
			outline.default_color = Color(1.0, 0.0, 0.47, 1.0)
			glow.points = closed_pts
			glow.default_color = Color(1.0, 0.0, 0.47, 0.15)

func _physics_process(delta: float) -> void:
	time_elapsed += delta
	position.y += speed * delta
	
	# Gentle pulsing glow
	var pulse = 0.8 + sin(time_elapsed * 5.0) * 0.2
	scale = Vector2(pulse, pulse)
	
	# Gentle floating side-to-side
	position.x += sin(time_elapsed * 3.0) * 0.5
	
	# Remove if off-screen
	if position.y > 1350:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	print("[Pickup] Area entered: ", area.name, " (groups: ", area.get_groups(), ")")
	if area.is_in_group("player"):
		apply_pickup(area)
		# Spawn a small flash effect
		_spawn_pickup_flash()
		queue_free()

func apply_pickup(player: Area2D) -> void:
	print("[Pickup] Applying pickup type: ", pickup_type, " to player. Current lives: ", player.lives, ", shield: ", player.shield)
	match pickup_type:
		PickupType.SHIELD:
			# Increase shield by 1, capped at maximum (5)
			player.shield = min(player.max_shield, player.shield + 1)
			player.update_hud()
			SoundManager.play("pickup_shield")
		PickupType.HEART:
			# Increase lives by 1, capped at maximum (3)
			player.lives = min(3, player.lives + 1)
			player.update_hud()
			SoundManager.play("pickup_heart")
	print("[Pickup] After applying - lives: ", player.lives, ", shield: ", player.shield)

func _spawn_pickup_flash() -> void:
	var flash_node = Node2D.new()
	flash_node.global_position = global_position
	get_tree().current_scene.add_child(flash_node)
	
	var flash = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in 6:
		var angle = TAU * i / 6
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	flash.polygon = points
	
	match pickup_type:
		PickupType.SHIELD:
			flash.color = Color(0.0, 0.94, 1.0, 0.8)
		PickupType.HEART:
			flash.color = Color(1.0, 0.0, 0.47, 0.8)
	
	flash_node.add_child(flash)
	
	var tween = flash_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "color:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(flash_node.queue_free)

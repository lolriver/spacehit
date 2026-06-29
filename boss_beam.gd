extends Area2D

var warning_time: float = 1.2
var active_time: float = 1.0

var elapsed_time: float = 0.0
var is_active: bool = false
var damage_delivered: bool = false

@onready var line: Line2D = $Line2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Keep collision shape disabled during the warning phase
	collision_shape.disabled = true
	line.width = 2.0
	line.default_color = Color(1.0, 0.0, 0.0, 0.4) # Translucent warning red
	
	area_entered.connect(_on_area_entered)
	
	# Span the beam vertically from Y=0 to Y=1150
	line.points = [Vector2(0, 0), Vector2(0, 1150)]
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40.0, 1150.0)
	collision_shape.shape = shape
	collision_shape.position = Vector2(0, 575.0)

func _process(delta: float) -> void:
	elapsed_time += delta
	if not is_active:
		# Flashing indicator
		var flash = Engine.get_frames_drawn() % 8 < 4
		line.default_color = Color(1.0, 0.0, 0.0, 0.8) if flash else Color(1.0, 0.0, 0.0, 0.2)
		if elapsed_time >= warning_time:
			# Fire laser beam
			is_active = true
			elapsed_time = 0.0
			collision_shape.disabled = false
			line.width = 38.0
			line.default_color = Color(1.0, 0.9, 1.0, 1.0) # Hot white core
			
			# Dynamic neon magenta background glow
			var glow = Line2D.new()
			glow.points = line.points
			glow.width = 54.0
			glow.default_color = Color(1.0, 0.0, 0.47, 0.65)
			add_child(glow)
			move_child(glow, 0)
			
			# Trigger screen shake
			var main = get_tree().current_scene
			if main and "shake_intensity" in main:
				main.shake_intensity = 20.0
	else:
		# Damage tick (recheck overlaps)
		if not damage_delivered:
			check_initial_overlaps()
			
		if elapsed_time >= active_time:
			# Smooth fade out
			modulate.a = lerp(modulate.a, 0.0, 8.0 * delta)
			if modulate.a < 0.05:
				queue_free()

func check_initial_overlaps() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("player"):
			_on_area_entered(area)

func _on_area_entered(area: Area2D) -> void:
	if is_active and area.is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage()
			damage_delivered = true

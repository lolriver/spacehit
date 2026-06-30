extends Node2D

# -- Star layer config --------------------------------------------------
const SCREEN_W := 720
const SCREEN_H := 1280
const WRAP_BOTTOM := 1300.0
const WRAP_TOP := -20.0

# Each entry: [count, color, speed, width, streak_length]
var _layer_defs: Array = [
	[60, Color(0.3, 0.4, 0.5, 0.4),  30.0, 1.0, 2.0],   # far
	[35, Color(0.5, 0.7, 0.9, 0.6),  60.0, 2.0, 4.0],   # mid
	[15, Color(0.7, 0.9, 1.0, 0.9), 120.0, 3.0, 8.0],   # near
]

# Runtime arrays – parallel to each Line2D node
var _stars: Array = []        # Array of { "node": Line2D, "speed": float }

# -- Nebula config -------------------------------------------------------
const NEBULA_COUNT := 4
const NEBULA_SPEED := 10.0
var _nebulae: Array = []      # Array of ColorRect

# -----------------------------------------------------------------------
func _ready() -> void:
	_build_stars()
	_build_nebulae()


func _process(delta: float) -> void:
	_move_stars(delta)
	_move_nebulae(delta)

# -----------------------------------------------------------------------
#  STARS
# -----------------------------------------------------------------------
func _build_stars() -> void:
	for def in _layer_defs:
		var count: int      = def[0]
		var color: Color    = def[1]
		var speed: float    = def[2]
		var width: float    = def[3]
		var streak: float   = def[4]

		for i in count:
			var star := Line2D.new()
			star.width = width
			star.default_color = color
			star.antialiased = true

			# Random start position across the full screen + a bit above
			var x := randf_range(0.0, SCREEN_W)
			var y := randf_range(WRAP_TOP, SCREEN_H)

			# Two-point vertical streak (top → bottom)
			star.add_point(Vector2(x, y))
			star.add_point(Vector2(x, y + streak))

			add_child(star)
			_stars.append({ "node": star, "speed": speed, "streak": streak })


func _move_stars(delta: float) -> void:
	for s in _stars:
		var star: Line2D = s["node"]
		var speed: float = s["speed"]
		var streak: float = s["streak"]
		var dy := speed * delta

		var p0 := star.get_point_position(0)
		p0.y += dy

		# Wrap when the top of the streak passes the bottom threshold
		if p0.y > WRAP_BOTTOM:
			p0.y = WRAP_TOP
			p0.x = randf_range(0.0, SCREEN_W)

		star.set_point_position(0, p0)
		star.set_point_position(1, Vector2(p0.x, p0.y + streak))

# -----------------------------------------------------------------------
#  NEBULA GLOW
# -----------------------------------------------------------------------
func _build_nebulae() -> void:
	var palette: Array[Color] = [
		Color(0.25, 0.15, 0.45, 0.04),   # deep purple
		Color(0.15, 0.20, 0.50, 0.05),   # royal blue
		Color(0.30, 0.10, 0.40, 0.03),   # violet
		Color(0.10, 0.25, 0.55, 0.06),   # cyan-blue
	]

	for i in NEBULA_COUNT:
		var rect := ColorRect.new()
		var w := randf_range(200.0, 400.0)
		var h := randf_range(200.0, 400.0)
		rect.size = Vector2(w, h)
		rect.color = palette[i]
		rect.position = Vector2(
			randf_range(-100.0, SCREEN_W - 100.0),
			randf_range(WRAP_TOP, SCREEN_H)
		)
		# Place nebulae behind stars (drawn first)
		rect.z_index = -1
		add_child(rect)
		_nebulae.append(rect)


func _move_nebulae(delta: float) -> void:
	for rect: ColorRect in _nebulae:
		rect.position.y += NEBULA_SPEED * delta
		if rect.position.y > WRAP_BOTTOM:
			rect.position.y = WRAP_TOP - rect.size.y
			rect.position.x = randf_range(-100.0, SCREEN_W - 100.0)

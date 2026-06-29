extends Node2D

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")

@onready var spawn_timer: Timer = $SpawnTimer
@onready var score_label: Label = %ScoreLabel
@onready var lives_label: Label = %LivesLabel
@onready var game_over_screen: Control = %GameOverScreen
@onready var final_score_label: Label = %FinalScoreLabel
@onready var player: Area2D = $Player

@onready var pause_overlay: Control = %PauseOverlay
@onready var popup_panel: PanelContainer = %PopupPanel
@onready var popup_label: Label = %PopupLabel

# Game States Enum
enum GameState {
	STATE_MAIN_MENU = 0,
	STATE_PLAYING = 1,
	STATE_PAUSED = 2,
	STATE_LEVEL_COMPLETE = 3,
	STATE_GAME_OVER = 4,
	STATE_VICTORY = 5,
	STATE_NAME_ENTRY = 6,
	STATE_SETTINGS_PANEL = 7,
	STATE_LEADERBOARD_PANEL = 8,
	STATE_MISSION_PANEL = 9
}

var current_state: int = GameState.STATE_MAIN_MENU

# Persistent Game Settings & High Scores
var sensitivity: float = 1.6
var high_scores: Array = []

# Game Progression stats
var score: int = 0
var current_level: int = 1
var level_goal_kills: int = 15
var level_current_kills: int = 0

var viewport_width: float = 720.0

# Screen Shake Variables
var shake_intensity: float = 0.0
var shake_decay: float = 5.0

# Styles for Segmented Bars
var style_empty: StyleBoxFlat
var style_shield_full: StyleBoxFlat
var style_boost_full: StyleBoxFlat

func _ready() -> void:
	viewport_width = get_viewport_rect().size.x
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Initialize HUD segmented bar graphics
	init_bar_styles()
	
	# Load saved configurations
	load_settings()
	load_high_scores()
	
	# Connect core UI signals
	%PlayBtn.pressed.connect(start_game)
	%MenuLeaderboardBtn.pressed.connect(func(): set_state(GameState.STATE_LEADERBOARD_PANEL))
	%MenuSettingsBtn.pressed.connect(func(): set_state(GameState.STATE_SETTINGS_PANEL))
	
	%PauseButton.pressed.connect(toggle_pause)
	%ResumeButton.pressed.connect(toggle_pause)
	%BoostButton.button_down.connect(_on_boost_button_down)
	%BoostButton.button_up.connect(_on_boost_button_up)
	
	# Sidebar panel buttons
	%MissionBtn.pressed.connect(func(): set_state(GameState.STATE_MISSION_PANEL))
	%LeaderboardBtn.pressed.connect(func(): set_state(GameState.STATE_LEADERBOARD_PANEL))
	%SettingsBtn.pressed.connect(func(): set_state(GameState.STATE_SETTINGS_PANEL))
	
	# Settings sub-screen buttons
	%SensLessBtn.pressed.connect(func(): adjust_sensitivity(-0.2))
	%SensMoreBtn.pressed.connect(func(): adjust_sensitivity(0.2))
	%ResetScoresBtn.pressed.connect(reset_high_scores)
	%SettingsBackBtn.pressed.connect(func(): set_state(GameState.STATE_MAIN_MENU))
	
	# Panel close buttons
	%CloseLeaderboardBtn.pressed.connect(close_sub_panel)
	%CloseMissionBtn.pressed.connect(close_sub_panel)
	
	# Progression screen transitions
	%SubmitScoreBtn.pressed.connect(submit_high_score)
	%NextLevelBtn.pressed.connect(advance_level)
	%VictoryBackBtn.pressed.connect(func(): set_state(GameState.STATE_MAIN_MENU))
	
	# Set initial screen visibility
	set_state(GameState.STATE_MAIN_MENU)

func init_bar_styles() -> void:
	style_empty = StyleBoxFlat.new()
	style_empty.bg_color = Color(0.02, 0.02, 0.05, 0.5)
	style_empty.border_width_left = 1
	style_empty.border_width_top = 1
	style_empty.border_width_right = 1
	style_empty.border_width_bottom = 1
	style_empty.border_color = Color(0.1, 0.3, 0.4, 0.3)
	style_empty.set_corner_radius_all(2)

	style_shield_full = StyleBoxFlat.new()
	style_shield_full.bg_color = Color(0.0, 0.94, 1.0, 1.0)
	style_shield_full.shadow_color = Color(0.0, 0.94, 1.0, 0.6)
	style_shield_full.shadow_size = 4
	style_shield_full.set_corner_radius_all(2)

	style_boost_full = StyleBoxFlat.new()
	style_boost_full.bg_color = Color(1.0, 0.0, 0.47, 1.0)
	style_boost_full.shadow_color = Color(1.0, 0.0, 0.47, 0.6)
	style_boost_full.shadow_size = 4
	style_boost_full.set_corner_radius_all(2)

func _process(delta: float) -> void:
	# Screen Shake Handler
	if shake_intensity > 0.0:
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		if shake_intensity < 0.1:
			shake_intensity = 0.0
			position = Vector2.ZERO
		else:
			position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))

func set_state(new_state: int) -> void:
	current_state = new_state
	
	# Manage tree pausing
	get_tree().paused = (new_state == GameState.STATE_PAUSED)
	
	# Control screen visibilities
	%MainMenuScreen.visible = (new_state == GameState.STATE_MAIN_MENU)
	%HUD.visible = (new_state == GameState.STATE_PLAYING or new_state == GameState.STATE_PAUSED)
	%PauseOverlay.visible = (new_state == GameState.STATE_PAUSED)
	%SettingsPanel.visible = (new_state == GameState.STATE_SETTINGS_PANEL)
	%LeaderboardPanel.visible = (new_state == GameState.STATE_LEADERBOARD_PANEL)
	%MissionPanel.visible = (new_state == GameState.STATE_MISSION_PANEL)
	%NameEntryScreen.visible = (new_state == GameState.STATE_NAME_ENTRY)
	%LevelCompleteScreen.visible = (new_state == GameState.STATE_LEVEL_COMPLETE)
	%VictoryScreen.visible = (new_state == GameState.STATE_VICTORY)
	%GameOverScreen.visible = (new_state == GameState.STATE_GAME_OVER)
	
	# State-specific logic initialization
	if new_state == GameState.STATE_MAIN_MENU:
		clear_game_entities()
		if player:
			player.hide()
			player.set_process(false)
		update_menu_high_score()
	elif new_state == GameState.STATE_PLAYING:
		if spawn_timer.is_stopped():
			spawn_timer.start()
		if player:
			player.show()
			player.set_process(true)
	elif new_state == GameState.STATE_LEADERBOARD_PANEL:
		render_leaderboard_list()
	elif new_state == GameState.STATE_MISSION_PANEL:
		update_mission_intel()
	elif new_state == GameState.STATE_NAME_ENTRY:
		%NameEntryScoreLabel.text = "FINAL SCORE: " + str(score)
		%NameInput.text = ""
		%NameInput.grab_focus()
	elif new_state == GameState.STATE_VICTORY:
		%VictoryScoreLabel.text = "FINAL SCORE: " + str(score)
		clear_game_entities()
	elif new_state == GameState.STATE_LEVEL_COMPLETE:
		# Clear standard entities to prevent overlap issues
		clear_game_entities()

func clear_game_entities() -> void:
	for child in get_children():
		if child.is_in_group("enemies") or child.is_in_group("lasers") or child is CPUParticles2D:
			child.queue_free()

func start_game() -> void:
	score = 0
	current_level = 1
	level_goal_kills = 15
	level_current_kills = 0
	
	update_score_label()
	
	if player:
		player.reset_player_stats()
		player.sensitivity = sensitivity
		
	set_state(GameState.STATE_PLAYING)

func _on_spawn_timer_timeout() -> void:
	spawn_enemy()

func spawn_enemy() -> void:
	if current_state != GameState.STATE_PLAYING or get_tree().paused:
		return
		
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		var spawn_x = randf_range(40.0, viewport_width - 40.0)
		enemy.position = Vector2(spawn_x, -50.0)
		
		# Probability matrix based on Level
		var selected_type = 0 # NORMAL
		var roll = randf()
		
		if current_level == 2:
			if roll < 0.30:
				selected_type = 1 # FAST
		elif current_level == 3:
			if roll < 0.15:
				selected_type = 2 # HEAVY
			elif roll < 0.45:
				selected_type = 1 # FAST
				
		enemy.enemy_type = selected_type
		
		# Speed parameters per level
		var base_speed_min = 200.0 + (score / 10.0) * 10.0
		var base_speed_max = 350.0 + (score / 10.0) * 15.0
		if selected_type == 1: # Fast
			base_speed_min *= 1.6
			base_speed_max *= 1.6
		elif selected_type == 2: # Heavy
			base_speed_min *= 0.7
			base_speed_max *= 0.7
			
		enemy.speed = randf_range(clamp(base_speed_min, 150.0, 600.0), clamp(base_speed_max, 250.0, 900.0))
		add_child(enemy)

func add_score(amount: int) -> void:
	if current_state != GameState.STATE_PLAYING:
		return
	score += amount
	update_score_label()
	
	# Increment level progression
	level_current_kills += 1
	
	# Check Level Clear condition
	if level_current_kills >= level_goal_kills:
		trigger_level_clear()
	else:
		# Gradually increase spawn rate in normal play
		var new_wait_time = 1.2 - (score / 10.0) * 0.04
		# Level 2 starts faster, Level 3 even faster
		var min_wait = 0.35
		if current_level == 2: min_wait = 0.3
		elif current_level == 3: min_wait = 0.25
		spawn_timer.wait_time = max(min_wait, new_wait_time)

func update_score_label() -> void:
	if score_label:
		score_label.text = str(score)

func update_player_stats(lives: int, shield: int, boost: float) -> void:
	if lives_label:
		lives_label.text = str(lives)
	
	# Update Shield Bar UI
	if %ShieldBar:
		for i in range(%ShieldBar.get_child_count()):
			var cell = %ShieldBar.get_child(i)
			if i < shield:
				cell.add_theme_stylebox_override("panel", style_shield_full)
			else:
				cell.add_theme_stylebox_override("panel", style_empty)
				
	# Update Boost Bar UI
	if %BoostBar:
		var boost_level = int(round(boost))
		for i in range(%BoostBar.get_child_count()):
			var cell = %BoostBar.get_child(i)
			if i < boost_level:
				cell.add_theme_stylebox_override("panel", style_boost_full)
			else:
				cell.add_theme_stylebox_override("panel", style_empty)

func spawn_player_hit_effect(hit_position: Vector2) -> void:
	shake_intensity = 15.0
	var explosion_scene = preload("res://explosion.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = hit_position
		explosion.scale = Vector2(1.5, 1.5)
		add_child(explosion)

func trigger_level_clear() -> void:
	# Fully restore player system shields as completion bonus
	if player:
		player.shield = player.max_shield
		player.update_hud()
		
	set_state(GameState.STATE_LEVEL_COMPLETE)

func advance_level() -> void:
	if current_level == 1:
		current_level = 2
		level_goal_kills = 30
		level_current_kills = 0
		spawn_timer.wait_time = 1.0
		set_state(GameState.STATE_PLAYING)
	elif current_level == 2:
		current_level = 3
		level_goal_kills = 50
		level_current_kills = 0
		spawn_timer.wait_time = 0.85
		set_state(GameState.STATE_PLAYING)
	else:
		# Level 3 completed -> game victory!
		if check_high_score_eligibility():
			set_state(GameState.STATE_NAME_ENTRY)
		else:
			set_state(GameState.STATE_VICTORY)

func trigger_game_over() -> void:
	if current_state == GameState.STATE_GAME_OVER or current_state == GameState.STATE_NAME_ENTRY:
		return
		
	if player:
		player.hide()
		player.set_process(false)
		player.set_deferred("monitoring", false)
		player.set_deferred("monitorable", false)
		
	if final_score_label:
		final_score_label.text = "FINAL SCORE: " + str(score)
		
	if check_high_score_eligibility():
		set_state(GameState.STATE_NAME_ENTRY)
	else:
		set_state(GameState.STATE_GAME_OVER)

func toggle_pause() -> void:
	if current_state != GameState.STATE_PLAYING and current_state != GameState.STATE_PAUSED:
		return
		
	if current_state == GameState.STATE_PLAYING:
		set_state(GameState.STATE_PAUSED)
	else:
		set_state(GameState.STATE_PLAYING)

func _on_boost_button_down() -> void:
	if player:
		player.is_boost_button_pressed = true

func _on_boost_button_up() -> void:
	if player:
		player.is_boost_button_pressed = false

func show_popup(text: String) -> void:
	if popup_label and popup_panel:
		popup_label.text = text
		popup_panel.show()
		var t = get_tree().create_timer(1.5)
		t.timeout.connect(func(): popup_panel.hide())

# Sidebar settings page controls
func adjust_sensitivity(amount: float) -> void:
	sensitivity = clamp(sensitivity + amount, 1.0, 3.0)
	%SensValueLabel.text = "%.1f" % sensitivity
	if player:
		player.sensitivity = sensitivity
	save_settings()

func close_sub_panel() -> void:
	# Closes Leaderboard or Mission control panels, returning back to Menu or Active Play
	if player and player.visible:
		set_state(GameState.STATE_PLAYING)
	else:
		set_state(GameState.STATE_MAIN_MENU)

# File Persistance Layer
func load_high_scores() -> void:
	if FileAccess.file_exists("user://high_scores.json"):
		var file = FileAccess.open("user://high_scores.json", FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_err = json.parse(json_string)
		if parse_err == OK:
			if json.data is Array:
				high_scores = json.data
				return
				
	# Load default scoreboard values
	high_scores = [
		{"name": "COMMANDER", "score": 1000},
		{"name": "VECTORS", "score": 600},
		{"name": "NEON", "score": 400},
		{"name": "ORION", "score": 200},
		{"name": "SOLAR", "score": 50}
	]
	save_high_scores()

func save_high_scores() -> void:
	var file = FileAccess.open("user://high_scores.json", FileAccess.WRITE)
	var json_string = JSON.stringify(high_scores)
	file.store_string(json_string)
	file.close()

func load_settings() -> void:
	if FileAccess.file_exists("user://settings.json"):
		var file = FileAccess.open("user://settings.json", FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_err = json.parse(json_string)
		if parse_err == OK:
			if json.data is Dictionary:
				sensitivity = json.data.get("sensitivity", 1.6)
				%SensValueLabel.text = "%.1f" % sensitivity
				return
				
	sensitivity = 1.6
	%SensValueLabel.text = "%.1f" % sensitivity

func save_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	var settings_data = {"sensitivity": sensitivity}
	var json_string = JSON.stringify(settings_data)
	file.store_string(json_string)
	file.close()

func reset_high_scores() -> void:
	high_scores = [
		{"name": "COMMANDER", "score": 1000},
		{"name": "VECTORS", "score": 600},
		{"name": "NEON", "score": 400},
		{"name": "ORION", "score": 200},
		{"name": "SOLAR", "score": 50}
	]
	save_high_scores()
	show_popup("Scores Resetted!")

func update_menu_high_score() -> void:
	if high_scores.size() > 0 and %MenuHighScoreLabel:
		%MenuHighScoreLabel.text = "HIGH SCORE: " + str(high_scores[0]["score"])

func check_high_score_eligibility() -> bool:
	if score <= 0:
		return false
	if high_scores.size() < 5:
		return true
	var lowest_score = high_scores[-1]["score"]
	return score > lowest_score

func submit_high_score() -> void:
	var name_text = %NameInput.text.strip_edges().to_upper()
	if name_text == "":
		name_text = "PILOT"
		
	# Insert score
	high_scores.append({"name": name_text, "score": score})
	# Sort descending
	high_scores.sort_custom(func(a, b): return a["score"] > b["score"])
	# Keep top 5
	if high_scores.size() > 5:
		high_scores.resize(5)
		
	save_high_scores()
	set_state(GameState.STATE_LEADERBOARD_PANEL)

func render_leaderboard_list() -> void:
	if not %ScoresList:
		return
		
	for child in %ScoresList.get_children():
		child.queue_free()
		
	for i in range(high_scores.size()):
		var entry = high_scores[i]
		var label = Label.new()
		label.text = "%d.  %-9s  -  %d" % [i + 1, entry["name"], entry["score"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		
		# Visual styling for podium places
		if i == 0:
			label.add_theme_color_override("font_color", Color(1.0, 0.8, 0, 1.0)) # Gold
		elif i == 1:
			label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0)) # Silver
		elif i == 2:
			label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2, 1.0)) # Bronze
		else:
			label.add_theme_color_override("font_color", Color(0, 0.94, 1.0, 0.8)) # Standard Cyan
			
		%ScoresList.add_child(label)

func update_mission_intel() -> void:
	if not %MissionLevelLabel:
		return
	
	%MissionLevelLabel.text = "LEVEL " + str(current_level)
	%MissionProgressLabel.text = "GOAL PROGRESS: %d / %d" % [level_current_kills, level_goal_kills]
	
	match current_level:
		1:
			%MissionDescLabel.text = "Objective: Destroy 15 falling hazards. Maintain shield recharge cycles to clear the outer sector."
		2:
			%MissionDescLabel.text = "Objective: Destroy 30 hazard variants. Extreme solar flares have spawned small, ultra-fast meteors. Enhance firing speeds using Boost Overdrive."
		3:
			%MissionDescLabel.text = "Objective: Destroy 50 hazard threats. Heavy multi-layer anomalies detected. Focus sustained fire to break them apart into fragments."

func _input(event: InputEvent) -> void:
	# Touch inputs for transitions
	var is_tap = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if is_tap:
		if current_state == GameState.STATE_GAME_OVER:
			set_state(GameState.STATE_MAIN_MENU)
		elif current_state == GameState.STATE_VICTORY:
			set_state(GameState.STATE_MAIN_MENU)

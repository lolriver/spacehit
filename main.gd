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

@onready var boss_panel: PanelContainer = %BossPanel
@onready var boss_progress_bar: ProgressBar = %BossProgressBar

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

# Game Progression stats (Infinite Mode)
var score: int = 0
var current_level: int = 1 # Serves as current Stage
var level_goal_kills: int = 15
var level_current_kills: int = 0

# Boss State
var is_boss_active: bool = false
var boss_health: int = 0
var boss_max_health: int = 0

var viewport_width: float = 720.0

# Screen Shake Variables
var shake_intensity: float = 0.0
var shake_decay: float = 5.0

# Styles for Segmented Bars & Boss HUD
var style_empty: StyleBoxFlat
var style_shield_full: StyleBoxFlat
var style_boost_full: StyleBoxFlat
var style_boss_bg: StyleBoxFlat
var style_boss_fill: StyleBoxFlat

func _ready() -> void:
	viewport_width = get_viewport_rect().size.x
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Initialize HUD styleboxes dynamically
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

	style_boss_bg = StyleBoxFlat.new()
	style_boss_bg.bg_color = Color(0.02, 0.02, 0.05, 0.75)
	style_boss_bg.border_width_left = 1
	style_boss_bg.border_width_top = 1
	style_boss_bg.border_width_right = 1
	style_boss_bg.border_width_bottom = 1
	style_boss_bg.border_color = Color(1.0, 0.0, 0.47, 0.5)
	style_boss_bg.set_corner_radius_all(4)

	style_boss_fill = StyleBoxFlat.new()
	style_boss_fill.bg_color = Color(1.0, 0.0, 0.47, 1.0)
	style_boss_fill.shadow_color = Color(1.0, 0.0, 0.47, 0.6)
	style_boss_fill.shadow_size = 4
	style_boss_fill.set_corner_radius_all(4)

	if boss_progress_bar:
		boss_progress_bar.add_theme_stylebox_override("background", style_boss_bg)
		boss_progress_bar.add_theme_stylebox_override("fill", style_boss_fill)

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
		is_boss_active = false
		if boss_panel:
			boss_panel.hide()
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
		if %Sub:
			%Sub.text = "STAGE " + str(current_level)
	elif new_state == GameState.STATE_LEADERBOARD_PANEL:
		render_leaderboard_list()
	elif new_state == GameState.STATE_MISSION_PANEL:
		update_mission_intel()
	elif new_state == GameState.STATE_NAME_ENTRY:
		%NameEntryScoreLabel.text = "FINAL SCORE: " + str(score)
		%NameInput.text = ""
		%NameInput.grab_focus()
	elif new_state == GameState.STATE_LEVEL_COMPLETE:
		clear_game_entities()

func clear_game_entities() -> void:
	for child in get_children():
		if child.is_in_group("enemies") or child.is_in_group("lasers") or child.is_in_group("enemy_bullets") or child is CPUParticles2D:
			child.queue_free()

func start_game() -> void:
	score = 0
	current_level = 1
	level_goal_kills = 15
	level_current_kills = 0
	is_boss_active = false
	if boss_panel:
		boss_panel.hide()
	
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
		
	# Boss Spawn Control (Every 5th stage: 5, 10, 15, 20, 25...)
	if current_level % 5 == 0:
		if not is_boss_active:
			is_boss_active = true
			var boss = enemy_scene.instantiate()
			boss.enemy_type = 5 # TYPE_BOSS
			boss.position = Vector2(360.0, -120.0)
			boss.speed = 70.0
			add_child(boss)
		else:
			# Background meteors at 15% rate during boss fight
			if randf() < 0.15:
				var meteor = enemy_scene.instantiate()
				meteor.enemy_type = 1 # TYPE_FAST
				meteor.position = Vector2(randf_range(40.0, viewport_width - 40.0), -50.0)
				meteor.speed = randf_range(320.0, 480.0)
				add_child(meteor)
		return
		
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		var spawn_x = randf_range(40.0, viewport_width - 40.0)
		enemy.position = Vector2(spawn_x, -50.0)
		
		# Select enemy type based on Stage Probability weights
		var selected_type = 0 # NORMAL
		var roll = randf()
		
		match current_level:
			1:
				selected_type = 0 # 100% Normal
			2:
				selected_type = 1 if roll < 0.30 else 0 # 30% Fast, 70% Normal
			3:
				# 45% Normal, 30% Fast, 25% Kamikaze
				if roll < 0.25:
					selected_type = 3 # KAMIKAZE
				elif roll < 0.55:
					selected_type = 1 # FAST
				else:
					selected_type = 0
			4:
				# 30% Normal, 30% Fast, 20% Kamikaze, 20% Fighter
				if roll < 0.20:
					selected_type = 4 # FIGHTER
				elif roll < 0.40:
					selected_type = 3 # KAMIKAZE
				elif roll < 0.70:
					selected_type = 1 # FAST
				else:
					selected_type = 0
			6:
				# 40% Normal, 30% Fast, 15% Heavy, 15% Drones
				if roll < 0.15:
					selected_type = 8 # DRONE
				elif roll < 0.30:
					selected_type = 2 # HEAVY
				elif roll < 0.60:
					selected_type = 1 # FAST
				else:
					selected_type = 0
			7:
				# 45% Normal, 30% Fast, 25% Stealth
				if roll < 0.25:
					selected_type = 6 # STEALTH
				elif roll < 0.55:
					selected_type = 1 # FAST
				else:
					selected_type = 0
			8:
				# 45% Normal, 30% Fast, 25% Mine
				if roll < 0.25:
					selected_type = 7 # MINE
				elif roll < 0.55:
					selected_type = 1 # FAST
				else:
					selected_type = 0
			9, 11, 12, 13, 14, 16, 17, 18, 19:
				# Balanced selections (all 8 standard hazards)
				if roll < 0.12:
					selected_type = 8 # DRONE
				elif roll < 0.24:
					selected_type = 7 # MINE
				elif roll < 0.36:
					selected_type = 6 # STEALTH
				elif roll < 0.48:
					selected_type = 4 # FIGHTER
				elif roll < 0.60:
					selected_type = 3 # KAMIKAZE
				elif roll < 0.72:
					selected_type = 2 # HEAVY
				elif roll < 0.86:
					selected_type = 1 # FAST
				else:
					selected_type = 0
			_: # Post 20+ scaling stages
				if roll < 0.13:
					selected_type = 8 # DRONE
				elif roll < 0.26:
					selected_type = 7 # MINE
				elif roll < 0.39:
					selected_type = 6 # STEALTH
				elif roll < 0.52:
					selected_type = 4 # FIGHTER
				elif roll < 0.64:
					selected_type = 3 # KAMIKAZE
				elif roll < 0.76:
					selected_type = 2 # HEAVY
				elif roll < 0.88:
					selected_type = 1 # FAST
				else:
					selected_type = 0
				
		enemy.enemy_type = selected_type
		
		# Speed ranges scales with score
		var base_speed_min = 200.0 + (score / 10.0) * 8.0
		var base_speed_max = 350.0 + (score / 10.0) * 12.0
		if selected_type == 1: # Fast
			base_speed_min *= 1.6
			base_speed_max *= 1.6
		elif selected_type == 2: # Heavy
			base_speed_min *= 0.7
			base_speed_max *= 0.7
		elif selected_type == 3: # Kamikaze
			base_speed_min *= 1.1
			base_speed_max *= 1.1
		elif selected_type == 6: # Stealth
			base_speed_min *= 0.85
			base_speed_max *= 0.85
		elif selected_type == 7: # Mine
			base_speed_min *= 0.6
			base_speed_max *= 0.6
		elif selected_type == 8: # Drone
			base_speed_min *= 0.95
			base_speed_max *= 0.95
			
		enemy.speed = randf_range(clamp(base_speed_min, 100.0, 650.0), clamp(base_speed_max, 200.0, 980.0))
		add_child(enemy)

func add_score(amount: int) -> void:
	if current_state != GameState.STATE_PLAYING:
		return
	score += amount
	update_score_label()
	
	# Skip standard kill updates on Boss fights
	if current_level % 5 == 0:
		return
		
	level_current_kills += 1
	
	# Check Stage Clear
	if level_current_kills >= level_goal_kills:
		trigger_level_clear()
	else:
		# Gradually increase spawn rate in normal play
		var new_wait_time = 1.2 - (score / 10.0) * 0.04
		var min_wait = 0.35
		if current_level >= 10: min_wait = 0.18
		elif current_level >= 5: min_wait = 0.22
		elif current_level >= 2: min_wait = 0.28
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

# Boss HUD controls
func show_boss_health_bar(max_hp: int) -> void:
	if boss_panel and boss_progress_bar:
		boss_max_health = max_hp
		boss_progress_bar.max_value = max_hp
		boss_progress_bar.value = max_hp
		boss_panel.show()

func update_boss_health(hp: int, max_hp: int) -> void:
	if boss_progress_bar:
		boss_progress_bar.value = hp

func on_boss_defeated() -> void:
	is_boss_active = false
	if boss_panel:
		boss_panel.hide()
	trigger_level_clear()

func trigger_level_clear() -> void:
	# Fully restore player shields as a Stage Clear reward!
	if player:
		player.shield = player.max_shield
		player.update_hud()
		
	set_state(GameState.STATE_LEVEL_COMPLETE)

func advance_level() -> void:
	# Go to next stage infinitely!
	current_level += 1
	# Stage goal increases
	level_goal_kills = 15 + current_level * 5
	level_current_kills = 0
	
	# Adjust spawn rate based on level progression
	spawn_timer.wait_time = max(0.18, 1.2 - (current_level * 0.05))
	
	# Update HUD Subtitle
	if %Sub:
		%Sub.text = "STAGE " + str(current_level)
		
	set_state(GameState.STATE_PLAYING)

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
				
	# Default Scores
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
	
	%MissionLevelLabel.text = "STAGE " + str(current_level)
	
	if current_level % 5 == 0:
		%MissionProgressLabel.text = "GOAL: ELIMINATE BOSS TARGET"
		match current_level % 20:
			5:
				%MissionDescLabel.text = "Boss Fight: Vanguard Outpost. Heavy hexagonal satellite firing dual angled lasers. Dodging meteors is critical."
			10:
				%MissionDescLabel.text = "Boss Fight: Goliath Cruiser. Triangular dreadnought firing 3-way spread lasers. Triggers a reflecting cyan plasma shield periodically."
			15:
				%MissionDescLabel.text = "Boss Fight: Carrier Leviathan. Massive transport ship spawning supportive fighter jets and shooting homing purple lasers."
			0:
				%MissionDescLabel.text = "Boss Fight: Hyperion Dreadnought. Ultimate fortress firing sweeping radial rings and drawing center charging death beams."
	else:
		%MissionProgressLabel.text = "GOAL PROGRESS: %d / %d" % [level_current_kills, level_goal_kills]
		match current_level:
			1:
				%MissionDescLabel.text = "Objective: Destroy 15 falling hazards. Maintain shield recharge cycles to clear the outer sector."
			2:
				%MissionDescLabel.text = "Objective: Destroy 20 hazard variants. Small, ultra-fast meteors detected. Enhance firing speeds using Boost Overdrive."
			3:
				%MissionDescLabel.text = "Objective: Destroy 25 hazard variants. Shooting Stars detected: they charge directly towards your ship X position."
			4:
				%MissionDescLabel.text = "Objective: Destroy 30 threats. Fighter ships detected: they move in a zig-zag flight pattern and shoot bullets downwards."
			6:
				%MissionDescLabel.text = "Objective: Destroy 35 hazards. Hunter Drones active: they lock onto your horizontal position to fire continuous green streams."
			7:
				%MissionDescLabel.text = "Objective: Destroy 40 hazards. Stealth Bombers active: they remain mostly invisible but fade in to fire 3-way spreads."
			8:
				%MissionDescLabel.text = "Objective: Destroy 45 hazards. Gravity Mines active: shooting them detonates a dangerous radial burst of 8 shrapnel bullets."
			_:
				%MissionDescLabel.text = "Objective: Destroy %d threats. High threat levels. Mixed fleet active including standard, fast, heavy, stealth, mines, and drones." % level_goal_kills

func _input(event: InputEvent) -> void:
	# Touch inputs for transitions
	var is_tap = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if is_tap:
		if current_state == GameState.STATE_GAME_OVER:
			set_state(GameState.STATE_MAIN_MENU)
		elif current_state == GameState.STATE_VICTORY:
			set_state(GameState.STATE_MAIN_MENU)

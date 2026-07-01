extends Node

## Procedural Synth Sound Effects Manager
## Generates all sounds at startup using AudioStreamWAV with raw PCM synthesis.
## Zero external audio files — everything is math.

var sfx_player: AudioStreamPlayer
var sfx_playback: AudioStreamPlaybackPolyphonic

# Pre-generated sound cache
var sounds: Dictionary = {}

# Master volume control (0.0 to 1.0)
var master_volume: float = 0.8

const SAMPLE_RATE: int = 22050

func _ready() -> void:
	_setup_buses()
	_setup_player()
	_generate_all_sounds()

func _setup_buses() -> void:
	# Create dedicated SFX bus with space-themed effects
	var idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")
	
	# Subtle reverb for spacey echo
	var reverb = AudioEffectReverb.new()
	reverb.room_size = 0.25
	reverb.wet = 0.12
	reverb.dry = 0.88
	reverb.damping = 0.6
	AudioServer.add_bus_effect(idx, reverb)
	
	# Gentle lo-fi for retro crunch
	var distortion = AudioEffectDistortion.new()
	distortion.mode = AudioEffectDistortion.MODE_LOFI
	distortion.drive = 0.15
	AudioServer.add_bus_effect(idx, distortion)

func _setup_player() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	var poly = AudioStreamPolyphonic.new()
	poly.polyphony = 16
	sfx_player.stream = poly
	add_child(sfx_player)
	sfx_player.play()

func _generate_all_sounds() -> void:
	sounds["laser"] = _gen_laser()
	sounds["explosion"] = _gen_explosion()
	sounds["shield_hit"] = _gen_shield_hit()
	sounds["pickup_shield"] = _gen_pickup_shield()
	sounds["pickup_heart"] = _gen_pickup_heart()
	sounds["boss_entrance"] = _gen_boss_entrance()
	sounds["boost"] = _gen_boost()
	sounds["game_over"] = _gen_game_over()
	sounds["enemy_destroy"] = _gen_enemy_destroy()
	sounds["level_clear"] = _gen_level_clear()

func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not sfx_playback and sfx_player:
		sfx_playback = sfx_player.get_stream_playback()
	if sounds.has(sound_name) and sfx_playback:
		sfx_playback.play_stream(sounds[sound_name], 0, volume_db)

# ═══════════════════════════════════════════════
#  WAVEFORM GENERATORS
# ═══════════════════════════════════════════════

func _square(phase: float, duty: float = 0.5) -> float:
	return 1.0 if fmod(phase, 1.0) < duty else -1.0

func _triangle(phase: float) -> float:
	var p = fmod(phase, 1.0)
	return abs(p * 4.0 - 2.0) - 1.0

func _sawtooth(phase: float) -> float:
	return fmod(phase, 1.0) * 2.0 - 1.0

func _sine(phase: float) -> float:
	return sin(phase * TAU)

func _noise() -> float:
	return randf_range(-1.0, 1.0)

# ═══════════════════════════════════════════════
#  HELPER: Create AudioStreamWAV from sample array
# ═══════════════════════════════════════════════

func _samples_to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val = clampf(samples[i] * master_volume, -1.0, 1.0)
		var int_val = clampi(int(val * 32767.0), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	
	stream.data = data
	return stream

# ═══════════════════════════════════════════════
#  SOUND GENERATORS
# ═══════════════════════════════════════════════

func _gen_laser() -> AudioStreamWAV:
	## Premium sci-fi sine chirp with a soft transient click.
	## Much cleaner and less harsh than a square wave, pleasant even at high firing rates.
	var duration = 0.07 # 70ms
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var freq = lerpf(1200.0, 500.0, t)
		# Fast exponential decay for clean pluck/chirp feel
		var envelope = pow(1.0 - t, 2.5)
		
		# Pure sine wave for a smooth, pleasant tone
		var tone = _sine(phase) * envelope * 0.25
		
		# Tiny high-passed transient noise click at the very start (first 8ms) for impact
		var transient = _noise() * max(0.0, 1.0 - t * 12.0) * 0.08
		
		samples[i] = tone + transient
		phase += freq / SAMPLE_RATE
	
	return _samples_to_stream(samples)

func _gen_explosion() -> AudioStreamWAV:
	## White noise burst with low-frequency sine rumble layered in
	var duration = 0.45
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var rumble_phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var envelope = pow(1.0 - t, 2.5) # Fast exponential decay
		
		# Noise layer
		var noise_val = _noise() * envelope * 0.7
		
		# Low rumble (pitch drops from 120Hz to 40Hz)
		var rumble_freq = lerpf(120.0, 40.0, t)
		var rumble_val = _sine(rumble_phase) * envelope * 0.5
		rumble_phase += rumble_freq / SAMPLE_RATE
		
		samples[i] = noise_val + rumble_val
	
	return _samples_to_stream(samples)

func _gen_shield_hit() -> AudioStreamWAV:
	## Metallic ping — sine at 1200Hz with fast decay + subtle noise crackle
	var duration = 0.15
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var envelope = pow(1.0 - t, 3.0)
		var ping = _sine(phase) * envelope * 0.7
		var crackle = _noise() * envelope * 0.15 * (1.0 - t)
		samples[i] = ping + crackle
		phase += 1200.0 / SAMPLE_RATE
	
	return _samples_to_stream(samples)

func _gen_pickup_shield() -> AudioStreamWAV:
	## 3-note ascending triangle arpeggio: C5 → E5 → G5
	var notes = [523.25, 659.25, 783.99] # C5, E5, G5
	var note_duration = 0.08
	var total_duration = note_duration * notes.size()
	var num_samples = int(SAMPLE_RATE * total_duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var note_index = mini(int(t * notes.size()), notes.size() - 1)
		var freq = notes[note_index]
		var note_t = fmod(t * notes.size(), 1.0)
		var envelope = (1.0 - note_t * 0.4) * (1.0 - t * 0.3)
		var val = _triangle(phase) * envelope * 0.55
		samples[i] = val
		phase += freq / SAMPLE_RATE
	
	return _samples_to_stream(samples)

func _gen_pickup_heart() -> AudioStreamWAV:
	## 4-note ascending triangle arpeggio: C5 → E5 → G5 → C6 (warmer)
	var notes = [523.25, 659.25, 783.99, 1046.5] # C5, E5, G5, C6
	var note_duration = 0.07
	var total_duration = note_duration * notes.size()
	var num_samples = int(SAMPLE_RATE * total_duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var note_index = mini(int(t * notes.size()), notes.size() - 1)
		var freq = notes[note_index]
		var note_t = fmod(t * notes.size(), 1.0)
		var envelope = (1.0 - note_t * 0.3) * (1.0 - t * 0.2)
		# Mix triangle + sine for warmth
		var val = (_triangle(phase) * 0.4 + _sine(phase) * 0.6) * envelope * 0.5
		samples[i] = val
		phase += freq / SAMPLE_RATE
	
	return _samples_to_stream(samples)

func _gen_boss_entrance() -> AudioStreamWAV:
	## Low sawtooth rumble sweep + alarm pulse
	var duration = 0.9
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var rumble_phase = 0.0
	var alarm_phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		
		# Fade in then out
		var env_rumble = sin(t * PI) * 0.6
		
		# Low rumble sweep (60Hz → 35Hz)
		var rumble_freq = lerpf(60.0, 35.0, t)
		var rumble = _sawtooth(rumble_phase) * env_rumble
		rumble_phase += rumble_freq / SAMPLE_RATE
		
		# Alarm pulse (square wave at 3Hz modulating a 400Hz tone)
		var alarm_mod = max(0.0, _square(t * 3.0, 0.5))
		var alarm = _square(alarm_phase, 0.5) * alarm_mod * 0.3 * sin(t * PI)
		alarm_phase += 400.0 / SAMPLE_RATE
		
		# Noise layer
		var noise_layer = _noise() * env_rumble * 0.15
		
		samples[i] = rumble + alarm + noise_layer
	
	return _samples_to_stream(samples)

func _gen_boost() -> AudioStreamWAV:
	## Fast upward square-wave sweep — power-up whoosh
	var duration = 0.15
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var freq = lerpf(200.0, 1400.0, t * t) # Exponential sweep up
		var envelope = 1.0 - t * 0.6
		var val = _square(phase, 0.3) * envelope * 0.5
		samples[i] = val
		phase += freq / SAMPLE_RATE
	
	return _samples_to_stream(samples)

func _gen_game_over() -> AudioStreamWAV:
	## 3-note descending minor chord: G4 → Eb4 → C4, with long sustain
	var notes = [392.0, 311.13, 261.63] # G4, Eb4, C4
	var note_duration = 0.2
	var total_duration = note_duration * notes.size()
	var num_samples = int(SAMPLE_RATE * total_duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var note_index = mini(int(t * notes.size()), notes.size() - 1)
		var freq = notes[note_index]
		var note_t = fmod(t * notes.size(), 1.0)
		var envelope = (1.0 - note_t * 0.5) * (1.0 - t * 0.4)
		# Square wave for harsh retro feel
		var val = _square(phase, 0.5) * envelope * 0.45
		samples[i] = val
		phase += freq / SAMPLE_RATE
	
	return _samples_to_stream(samples)

func _gen_enemy_destroy() -> AudioStreamWAV:
	## Quick noise pop + sine blip
	var duration = 0.18
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var envelope = pow(1.0 - t, 2.0)
		
		# Noise pop (first 30% of sound)
		var noise_env = max(0.0, 1.0 - t * 3.33) * 0.5
		var noise_val = _noise() * noise_env
		
		# Sine ping at 700Hz descending to 400Hz
		var freq = lerpf(700.0, 400.0, t)
		var ping = _sine(phase) * envelope * 0.5
		phase += freq / SAMPLE_RATE
		
		samples[i] = noise_val + ping
	
	return _samples_to_stream(samples)

func _gen_level_clear() -> AudioStreamWAV:
	## Triumphant major chord arpeggio: C5 → E5 → G5 → C6 with sustain
	var notes = [523.25, 659.25, 783.99, 1046.5] # C5, E5, G5, C6
	var note_duration = 0.12
	var sustain = 0.15
	var total_duration = note_duration * notes.size() + sustain
	var num_samples = int(SAMPLE_RATE * total_duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	var phase = 0.0
	var phase2 = 0.0
	
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var arp_t = float(i) / float(SAMPLE_RATE)
		var note_index = mini(int(arp_t / note_duration), notes.size() - 1)
		var freq = notes[note_index]
		
		# Global fade out at the end
		var global_env = 1.0 if t < 0.7 else (1.0 - (t - 0.7) / 0.3)
		
		# Triangle for bright clean tone + octave harmony
		var val = _triangle(phase) * 0.4 + _sine(phase2) * 0.3
		val *= global_env * 0.55
		
		samples[i] = val
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 2.0) / SAMPLE_RATE # Octave up shimmer
	
	return _samples_to_stream(samples)

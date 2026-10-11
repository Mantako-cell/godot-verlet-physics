#=============================================================================
# VerletAudioSynth - Procedural Retro-Synthesizer for Physics SFX
# Generates zero-dependency procedural AudioStreamWAV audio in pure GDScript.
#=============================================================================
class_name VerletAudioSynth
extends Node

static var _snap_stream: AudioStreamWAV = null
static var _cut_stream: AudioStreamWAV = null
static var _thud_stream: AudioStreamWAV = null
static var _grapple_stream: AudioStreamWAV = null
static var _splash_stream: AudioStreamWAV = null


static func play_sound(tree: SceneTree, type: String, volume_db: float = -6.0) -> void:
	if not tree:
		return
	var stream: AudioStreamWAV = null
	match type:
		"snap":
			if not _snap_stream: _snap_stream = _build_snap_sound()
			stream = _snap_stream
		"cut":
			if not _cut_stream: _cut_stream = _build_cut_sound()
			stream = _cut_stream
		"thud":
			if not _thud_stream: _thud_stream = _build_thud_sound()
			stream = _thud_stream
		"grapple":
			if not _grapple_stream: _grapple_stream = _build_grapple_sound()
			stream = _grapple_stream
		"splash":
			if not _splash_stream: _splash_stream = _build_splash_sound()
			stream = _splash_stream

	if stream:
		var player = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = volume_db
		tree.root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)


static func _build_snap_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var samples: int = 2400 # ~0.11s
	var data = PackedByteArray()
	data.resize(samples)
	for i in range(samples):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 50.0)
		var freq: float = 1800.0 * exp(-t * 40.0)
		var val: float = (sin(t * freq * TAU) + (randf() * 2.0 - 1.0) * 0.4) * env
		data[i] = clampi(int(128.0 + val * 115.0), 0, 255)
	stream.data = data
	return stream


static func _build_cut_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var samples: int = 2800 # ~0.12s
	var data = PackedByteArray()
	data.resize(samples)
	for i in range(samples):
		var t: float = float(i) / 22050.0
		var env: float = sin(clampf(t / 0.12, 0.0, 1.0) * PI)
		var freq: float = 2400.0 - (t * 8000.0)
		var val: float = sin(t * freq * TAU) * env * 0.85
		data[i] = clampi(int(128.0 + val * 110.0), 0, 255)
	stream.data = data
	return stream


static func _build_thud_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var samples: int = 4410 # ~0.2s
	var data = PackedByteArray()
	data.resize(samples)
	for i in range(samples):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 18.0)
		var freq: float = 140.0 * exp(-t * 8.0)
		var val: float = sin(t * freq * TAU) * env
		data[i] = clampi(int(128.0 + val * 120.0), 0, 255)
	stream.data = data
	return stream


static func _build_grapple_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var samples: int = 3300 # ~0.15s
	var data = PackedByteArray()
	data.resize(samples)
	for i in range(samples):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 25.0)
		var freq: float = 400.0 + (t * 1200.0)
		var val: float = sin(t * freq * TAU) * env
		data[i] = clampi(int(128.0 + val * 115.0), 0, 255)
	stream.data = data
	return stream


static func _build_splash_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var samples: int = 3800 # ~0.17s
	var data = PackedByteArray()
	data.resize(samples)
	for i in range(samples):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 24.0)
		var bubble_freq: float = 340.0 + sin(t * 85.0) * 160.0
		var noise: float = (randf() * 2.0 - 1.0) * 0.6
		var bubble: float = sin(t * bubble_freq * TAU) * 0.45
		var val: float = (noise + bubble) * env
		data[i] = clampi(int(128.0 + val * 115.0), 0, 255)
	stream.data = data
	return stream


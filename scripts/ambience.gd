extends AudioStreamPlayer
class_name IndustrialAmbience

var phase_a: float = 0.0
var phase_b: float = 0.0
var noise_state: float = 0.0
var playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	bus = "Music"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.35
	stream = generator
	volume_db = -24.0
	play()

func _process(_delta: float) -> void:
	if not playing:
		return
	if playback == null:
		playback = get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := playback.get_frames_available()
	if frames <= 0:
		return
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var rate := 22050.0
	for i in range(frames):
		var low := sin(phase_a) * 0.48
		var high := sin(phase_b) * 0.10
		var pulse := sin(phase_a * 0.17) * 0.12
		noise_state = lerpf(noise_state, randf_range(-1.0, 1.0), 0.018)
		var sample := (low + high + pulse + noise_state * 0.035) * 0.055
		buffer[i] = Vector2(sample, sample)
		phase_a = fmod(phase_a + TAU * 48.0 / rate, TAU)
		phase_b = fmod(phase_b + TAU * 73.0 / rate, TAU)
	playback.push_buffer(buffer)

func stop_ambience() -> void:
	stop()
	playback = null

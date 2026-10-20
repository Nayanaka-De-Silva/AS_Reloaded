# Godot Audio Manager Skill

Audio, SFX, and music patterns for Godot 4.x.

## Audio Node Types

| Node | Use Case |
|------|----------|
| AudioStreamPlayer | Non-positional (music, UI sounds) |
| AudioStreamPlayer2D | 2D positional audio |
| AudioStreamPlayer3D | 3D positional audio |

## Audio Bus Setup

1. Go to **Project > Project Settings > Audio**
2. Create buses: Master → Music, Master → SFX, Master → UI
3. Add effects (reverb, compression) to buses as needed

## Basic Audio Manager (Autoload)

```gdscript
# audio_manager.gd
extends Node

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

func _ready() -> void:
    # Create music player
    music_player = AudioStreamPlayer.new()
    music_player.bus = "Music"
    add_child(music_player)
    
    # Create SFX player pool
    for i in SFX_POOL_SIZE:
        var player = AudioStreamPlayer.new()
        player.bus = "SFX"
        add_child(player)
        sfx_players.append(player)

func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
    if music_player.stream == stream and music_player.playing:
        return
    
    if music_player.playing and fade_in > 0:
        var tween = create_tween()
        tween.tween_property(music_player, "volume_db", -40, fade_in)
        await tween.finished
    
    music_player.stream = stream
    music_player.volume_db = 0
    music_player.play()

func stop_music(fade_out: float = 1.0) -> void:
    if not music_player.playing:
        return
    
    var tween = create_tween()
    tween.tween_property(music_player, "volume_db", -40, fade_out)
    await tween.finished
    music_player.stop()

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
    for player in sfx_players:
        if not player.playing:
            player.stream = stream
            player.volume_db = volume_db
            player.play()
            return
    
    # All players busy - use first one (interrupting oldest sound)
    sfx_players[0].stream = stream
    sfx_players[0].volume_db = volume_db
    sfx_players[0].play()
```

## One-Shot SFX Pattern

```gdscript
func play_sfx_oneshot(stream: AudioStream, pos: Vector2 = Vector2.ZERO) -> void:
    var player = AudioStreamPlayer2D.new()
    player.stream = stream
    player.bus = "SFX"
    player.global_position = pos
    add_child(player)
    player.play()
    player.finished.connect(player.queue_free)
```

## Randomized SFX (Variation)

```gdscript
# For footsteps, hits, etc. - avoid repetition
@export var footstep_sounds: Array[AudioStream] = []
var last_footstep_index: int = -1

func play_footstep() -> void:
    if footstep_sounds.is_empty():
        return
    
    # Pick random sound, avoiding the last one played
    var index = randi() % footstep_sounds.size()
    while index == last_footstep_index and footstep_sounds.size() > 1:
        index = randi() % footstep_sounds.size()
    
    last_footstep_index = index
    AudioManager.play_sfx(footstep_sounds[index])
```

## Using AudioStreamRandomizer

```gdscript
# In the Inspector, create an AudioStreamRandomizer resource
# Add multiple streams to it
# The engine will automatically randomize pitch/selection

@export var hit_sounds: AudioStreamRandomizer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func play_hit() -> void:
    audio_player.stream = hit_sounds
    audio_player.play()
```

## Volume Control

```gdscript
func set_music_volume(linear: float) -> void:
    # Convert linear (0-1) to decibels
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("Music"),
        linear_to_db(linear)
    )

func set_sfx_volume(linear: float) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("SFX"),
        linear_to_db(linear)
    )

func set_master_volume(linear: float) -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(linear))

func mute_bus(bus_name: String, muted: bool) -> void:
    AudioServer.set_bus_mute(
        AudioServer.get_bus_index(bus_name),
        muted
    )
```

## Crossfade Music

```gdscript
func crossfade_music(new_stream: AudioStream, duration: float = 2.0) -> void:
    var old_player = music_player
    
    # Create new player for crossfade
    var new_player = AudioStreamPlayer.new()
    new_player.stream = new_stream
    new_player.bus = "Music"
    new_player.volume_db = -40
    add_child(new_player)
    new_player.play()
    
    # Crossfade
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(old_player, "volume_db", -40, duration)
    tween.tween_property(new_player, "volume_db", 0, duration)
    
    await tween.finished
    old_player.stop()
    music_player = new_player
    old_player.queue_free()
```

## Positional 2D Audio

```gdscript
# Attach AudioStreamPlayer2D to moving objects
# Godot handles panning and attenuation automatically

extends CharacterBody2D

@onready var footstep_player: AudioStreamPlayer2D = $FootstepPlayer
@export var footstep_sound: AudioStream

func play_footstep() -> void:
    if not footstep_player.playing:
        footstep_player.stream = footstep_sound
        footstep_player.pitch_scale = randf_range(0.9, 1.1)
        footstep_player.play()
```

## Best Practices

- Use **WAV** for short SFX (no decoding delay)
- Use **OGG** for music (smaller file size, supports looping)
- Set up audio buses early - easier to balance later
- Pool AudioStreamPlayers for frequent SFX
- Use `max_polyphony` property for multi-instance sounds
- Preload frequently used sounds:
  ```gdscript
  const JUMP_SFX = preload("res://audio/sfx/jump.wav")
  ```
- Test audio balance with different volumes
- Add slight pitch variation (0.9-1.1) for repeated sounds

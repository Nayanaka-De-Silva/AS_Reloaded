# Godot Shader Basics Skill

Shader and VisualShader patterns for Godot 4.x.

## Shader Types

| Type | Use Case |
|------|----------|
| `shader_type canvas_item` | 2D sprites, UI, CanvasItem nodes |
| `shader_type spatial` | 3D materials |
| `shader_type particles` | GPU particles |
| `shader_type sky` | Sky/environment shaders |

## Basic 2D Shader Structure

```glsl
shader_type canvas_item;

// Uniforms (parameters controllable from GDScript)
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D noise_texture;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    color.rgb *= tint_color.rgb * intensity;
    COLOR = color;
}
```

## Common 2D Effects

### Flash White (Hit Effect)
```glsl
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    color.rgb = mix(color.rgb, vec3(1.0), flash_amount);
    COLOR = color;
}
```

### Outline
```glsl
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
    
    vec4 color = texture(TEXTURE, UV);
    if (outline > 0.0 && color.a == 0.0) {
        COLOR = outline_color;
    } else {
        COLOR = color;
    }
}
```

### Dissolve Effect
```glsl
shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float noise = texture(noise_texture, UV).r;
    
    if (noise < dissolve_amount) {
        discard;
    } else if (noise < dissolve_amount + edge_width) {
        color.rgb = edge_color.rgb;
    }
    
    COLOR = color;
}
```

## Controlling Shaders from GDScript

```gdscript
extends Sprite2D

@onready var material: ShaderMaterial = material as ShaderMaterial

func flash_white(duration: float = 0.1) -> void:
    material.set_shader_parameter("flash_amount", 1.0)
    await get_tree().create_timer(duration).timeout
    
    var tween = create_tween()
    tween.tween_method(
        func(value): material.set_shader_parameter("flash_amount", value),
        1.0, 0.0, 0.2
    )

func set_dissolve(amount: float) -> void:
    material.set_shader_parameter("dissolve_amount", amount)

func dissolve_out(duration: float = 1.0) -> void:
    var tween = create_tween()
    tween.tween_method(set_dissolve, 0.0, 1.0, duration)
```

## 3D Spatial Shader Structure

```glsl
shader_type spatial;
render_mode unshaded;  // or: blend_mix, depth_draw_opaque, etc.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color;

void fragment() {
    vec4 tex = texture(texture_albedo, UV);
    ALBEDO = tex.rgb * albedo.rgb;
    ALPHA = tex.a * albedo.a;
}
```

## VisualShader Tips

- Use VisualShader for prototyping or if you prefer node-based editing
- Right-click canvas to add nodes
- Common nodes: `Texture2D`, `ColorParameter`, `FloatParameter`
- Convert to code: VisualShader → Resource → Convert to ShaderMaterial

## Creating Shader Material in Code

```gdscript
func apply_custom_shader() -> void:
    var shader = preload("res://shaders/my_shader.gdshader")
    var mat = ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("tint_color", Color.RED)
    $Sprite2D.material = mat
```

## Best Practices

- Use uniforms for any value you might want to change at runtime
- Use `hint_range()` for float uniforms to get sliders in inspector
- Use `: source_color` hint for color uniforms
- Test shaders on target hardware (mobile performance differs)
- Use `render_mode unshaded` for pure visual effects (no lighting)
- Keep shaders simple; complex math per-pixel is expensive

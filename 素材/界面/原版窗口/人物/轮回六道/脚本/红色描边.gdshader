shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 3.0;

// Grayscale blend, coefficients verbatim from StyleUtil.getGrayFilter()
// (0.3086, 0.6094, 0.082 -- same as 禁用灰度.gdshader, NOT Rec.601 defaults).
// LunHuiYanPanel.setImageFilters:314-333 pushes getGrayFilter() on every stage
// ABOVE the attained one, and the red glow on the VIEWED one on top of that
// (AS3 filters array), so "viewed + not attained" = gray WITH the outline.
// This file must stay ASCII-only (Godot shader tokenizer rejects CJK, see
// 禁用灰度.gdshader's header note).
uniform float gray_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);

    if (original_color.a > 0.1) {
        if (gray_amount > 0.0) {
            float g = dot(original_color.rgb, vec3(0.3086, 0.6094, 0.082));
            original_color.rgb = mix(original_color.rgb, vec3(g), gray_amount);
        }
        COLOR = original_color;
    } else {
        float outline = 0.0;
        vec2 step = TEXTURE_PIXEL_SIZE * outline_width;
        
        outline += texture(TEXTURE, UV + vec2(-step.x, 0.0)).a;
        outline += texture(TEXTURE, UV + vec2(step.x, 0.0)).a;
        outline += texture(TEXTURE, UV + vec2(0.0, -step.y)).a;
        outline += texture(TEXTURE, UV + vec2(0.0, step.y)).a;
        
        if (outline > 0.0) {
            COLOR = outline_color;
        } else {
            COLOR = vec4(0.0);
        }
    }
}
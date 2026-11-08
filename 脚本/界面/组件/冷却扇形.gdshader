shader_type canvas_item;

// Cooldown pie for the bottom shortcut cells -- port of the original client's
// com/mxw/uifl/controls/GirdCool.as (created by MCell.showCoolDown():100-113).
//
//   GirdCool(color=0, alp=0.8, board=42, ellipse=10):
//     init():   fillRect 42x42 black, mask = drawRoundRect(0,0,42,42,10), rotation = -90
//     draw():   angle = lastTime / coolTime * 360     (lastTime = ELAPSED, not remaining)
//               fills everything except the wedge already swept -> the cell goes dark on
//               cast and the dark shrinks clockwise; angle > 360 -> destroy()
//
// So the covered region is the sector from angle A to 360, measured clockwise from
// 12 o'clock, where A = progress * TAU and progress = elapsed / total.
//
// This node is a ColorRect on top of the cell (added after the icon), so the shader only
// emits black with the right alpha -- it composites over whatever is underneath, exactly
// like Flash's beginFill(0, 0.8).
//
// TWO TRAPS, both hit for real on 2026-10-12:
//  1) This file must stay ASCII-only, comments included. Godot's shader tokenizer rejects
//     non-ASCII characters even inside // comments ("Unknown character") and the whole
//     shader then fails to compile.
//  2) `uniform float x : float = 5.0` does NOT compile -- after the colon only a hint is
//     allowed (hint_range, ...). When the shader fails, the ColorRect falls back to its
//     own default color = WHITE, so the cell shows a white block while every
//     node-property assertion still passes green. The gate therefore checks pixels.

//  3) `TAU` (and PI/FRAC_PI*/TAU...) is a **built-in shader constant** in Godot 4 --
//     redeclaring `const float TAU = ...` is a hard error ("Redefinition of 'TAU'") and
//     again leaves the ColorRect white.

uniform float progress = 0.0;			// elapsed / total
uniform float corner = 5.0;			// Flash ellipse=10 -> corner radius 5
uniform float cover_alpha = 0.8;		// GirdCool._alp

void fragment() {
	vec2 p = UV - vec2(0.5);
	// rounded-rect mask (drawRoundRect over the whole board)
	vec2 q = abs(p) - vec2(0.5) + vec2(corner / 42.0);
	float d = length(max(q, vec2(0.0))) - corner / 42.0;
	float inside = 1.0 - smoothstep(-0.5 / 42.0, 0.5 / 42.0, d);
	// angle clockwise from 12 o'clock, 0..TAU
	float ang = atan(p.x, -p.y);
	if (ang < 0.0) {
		ang += TAU;
	}
	float dark = inside * step(progress * TAU, ang);
	COLOR = vec4(0.0, 0.0, 0.0, dark * cover_alpha);
}

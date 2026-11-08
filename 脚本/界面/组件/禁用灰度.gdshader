shader_type canvas_item;

// Disabled-state grayscale, ported from the original client.
//
//   MButton3.updateState():
//     if (state != STATE_DISABLED) filters.push(StyleUtil.getLightFilter(skinFilters[state]));
//     else                         filters.push(StyleUtil.getGrayFilter());
//
//   StyleUtil.getGrayFilter() = new ColorMatrixFilter([
//     0.3086,0.6094,0.082,0,0,  0.3086,0.6094,0.082,0,0,
//     0.3086,0.6094,0.082,0,0,  0,0,0,1,0])
//
// i.e. plain luminance grayscale, offset column is 0.
// The coefficients are copied verbatim -- do NOT swap in vec3(0.299,0.587,0.114),
// that is Rec.601 and yields different values.
//
// Only the disabled state is gray. up/over/down are the SAME texture with a
// brightness offset (+0 / +30 / -40), not different art.
//
// NOTE: this file must stay ASCII-only. Godot's shader tokenizer rejects
// non-ASCII identifiers and even chokes on Chinese inside comments
// ("Tokenizer: Unknown character"). The long Chinese explanation lives in
// 功能窗口.gd next to the 禁用灰度材质() helper.

void fragment() {
	// In Godot 4 canvas_item shaders COLOR already holds texture * vertex color
	// at this point, so folding the grayscale into COLOR keeps modulate/alpha intact.
	// (There is no MODULATE builtin in fragment() -- using it fails to compile.)
	float gray = dot(COLOR.rgb, vec3(0.3086, 0.6094, 0.082));
	COLOR.rgb = vec3(gray);
}

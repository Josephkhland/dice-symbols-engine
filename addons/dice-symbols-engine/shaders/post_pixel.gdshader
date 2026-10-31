shader_type canvas_item;

// PS2-style pixel post-processing for the 3D dice tray view.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform int pixel_size : hint_range(1, 16) = 3;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float palette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.5;
uniform float shimmer : hint_range(0.0, 1.0) = 0.3;
uniform float poster_levels : hint_range(2.0, 64.0, 1.0) = 8.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	float cell = float(max(pixel_size, 1));
	vec2 cell_size = px * cell;

	// Snap to a coarse low-res grid (center of each big pixel).
	vec2 big = floor(SCREEN_UV / cell_size);
	vec2 uv = (big + vec2(0.5)) * cell_size;

	// PS2-style texture shimmer: wobble the sample around its grid cell.
	if (shimmer > 0.0) {
		float t = TIME * 0.5;
		vec2 ph = big;
		uv.x += sin(ph.x * 1.7 + ph.y * 2.3 + t) * shimmer * px.x;
		uv.y += sin(ph.y * 2.9 + ph.x * 1.3 - t) * shimmer * px.y;
	}

	vec3 col = texture(SCREEN_TEXTURE, clamp(uv, px, vec2(1.0) - px)).rgb;

	// Posterize to a small set of levels (bit-depth crunch).
	vec3 poster = floor(col * poster_levels) / max(poster_levels - 1.0, 1.0);
	col = mix(col, poster, palette_strength);

	// Ordered 2x2 dither to hide banding inside the low palette.
	if (dither_strength > 0.0) {
		vec2 parity = fract(big * vec2(0.5, 0.5));
		float bayer = fract(parity.x + 0.5 * parity.y);
		col += (bayer - 0.5) * dither_strength / max(poster_levels - 1.0, 1.0);
	}

	// Scanlines every other low-res row.
	float row = big.y;
	col *= 1.0 - scanline_strength * step(0.5, fract(row * 0.5));

	// Soft vignette.
	vec2 v = SCREEN_UV - vec2(0.5);
	float vig = 1.0 - vignette_strength
		* smoothstep(0.35, 0.9, length(v * vec2(1.0, 1.78)));
	col *= vig;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
// Timber — the ladder, chiefly, which is in every frame of the climbing half of the game.
//
// It was flat brown boxes. That is defensible at fifty metres and indefensible at arm's length,
// and arm's length is where the player spends the entire game: the stile is four inches from the
// camera for two hours, and it was one value of brown.
//
// Procedural for the same reason the brick is — binary is the half of this project agents cannot
// author or review — and in the piece's own space rather than in world space, because a ladder
// section is a sawn length of Columbian pine and its grain runs down it, not down the chimney.
//
// The trick that makes that possible on a MultiMesh: the instance's scale comes out of
// MODEL_MATRIX's column lengths, so VERTEX times that scale is the position *within this piece,
// in metres*. Grain along local Y then means grain along the length of a stile and along the
// length of a rung, from one mesh, with no per-instance data to keep in step.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 wood_light : source_color = vec3(0.52, 0.39, 0.23);
uniform vec3 wood_dark : source_color = vec3(0.27, 0.19, 0.11);
// Grey. Softwood left out in a Pennine winter goes silver, and a jack's ladders live outdoors.
uniform vec3 weathered : source_color = vec3(0.45, 0.43, 0.40);
uniform float weather = 0.42;
// Metres between grain lines across the face of the piece.
uniform float grain_pitch = 0.011;
uniform float relief = 0.0006;

varying vec3 piece;
varying float piece_id;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How dark this point is, 0..1 — the field the colour and the bump are both read from, so the
// two cannot drift apart.
float grain(vec3 p, float id) {
	// The grain wanders down the length and is not parallel to the saw. Without this it is a
	// barcode, which is what every first attempt at wood looks like.
	float wander = (vnoise(vec2(p.y * 0.9, id * 37.0)) - 0.5) * 0.020
		+ (vnoise(vec2(p.y * 4.1, id * 11.0)) - 0.5) * 0.004;
	float across = p.x + p.z * 0.35 + wander;
	float ring = abs(fract(across / grain_pitch) - 0.5) * 2.0;
	// Latewood is a narrow dark band; earlywood is the wide pale space between. An even
	// sine reads as corduroy.
	float band = smoothstep(0.62, 0.95, ring);
	// A coarser variation on top, so a face is not one repeating pitch.
	band = clamp(band * (0.55 + 0.75 * vnoise(vec2(across * 22.0, p.y * 1.7))), 0.0, 1.0);
	return band;
}

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	piece = VERTEX * s;
	// Stable per piece, and it has to be *stable*.
	//
	// It was hashed off the instance's x and z, and a ladder section bows under the man on it —
	// which moves every piece of it horizontally, every frame, which re-rolled its colour and its
	// weathering thirty times a second. The ladder shimmered. Height does not change when a
	// section bows (the bow is horizontal), and INSTANCE_ID does not change at all, so between
	// them they identify a piece without tracking it.
	piece_id = hash(vec2(float(INSTANCE_ID) * 0.37, floor(MODEL_MATRIX[3].y * 2.0)));
}

void fragment() {
	float px = max(max(fwidth(piece.x), fwidth(piece.z)), 1e-5);
	float resolvable = clamp((grain_pitch - px) / grain_pitch, 0.0, 1.0);

	float g = grain(piece, piece_id);
	vec3 col = mix(wood_light, wood_dark, g * resolvable);
	// Per-piece cast, and per-piece weathering: a section that has been on a chimney for ten
	// seasons is not the colour of one bought last year.
	col *= 0.84 + 0.30 * piece_id;
	col = mix(col, weathered, weather * (0.45 + 0.55 * hash(vec2(piece_id, 7.3))));
	// Grubby at the ends, where hands and boots go.
	ALBEDO = col;

	// Raised grain. Softwood weathers proud along the hard bands, which is why an old ladder is
	// rough under the hand and why the low sun finds every one of them.
	if (resolvable > 0.01) {
		float e = max(px * 1.2, 0.0004);
		float g0 = g * relief;
		vec2 slope = vec2(grain(piece + vec3(e, 0.0, 0.0), piece_id) * relief - g0,
			grain(piece + vec3(0.0, 0.0, e), piece_id) * relief - g0) / e * resolvable;
		vec3 n_world = normalize(NORMAL * mat3(VIEW_MATRIX));
		// Only across the grain; along it there is nothing to feel.
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), n_world) + vec3(1e-5));
		vec3 up = normalize(cross(n_world, side));
		NORMAL = normalize(normalize(n_world - side * slope.x - up * slope.y)
			* mat3(INV_VIEW_MATRIX));
	}

	ROUGHNESS = mix(0.72, 0.94, g * resolvable);
	SPECULAR = mix(0.30, 0.12, weather);
}

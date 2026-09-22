// The ground at the foot of the stack — the other half of ENV-002.
//
// It was one plane of one colour, four kilometres across, and it read as exactly that: a sheet of
// olive card with a chimney standing on it and a hard line where it met the sky. The town gave the
// distance its parallax and nothing gave the *near* ground anything at all, which is a problem on
// a level that opens with a two-minute walk across it.
//
// Three surfaces, blended by distance from the stack rather than by a texture: setts round the
// base where a century of carts has worn the ground to stone, cinder and clinker over the yard,
// and sooted grass past the wall. Each fades out as its features get smaller than a pixel, the
// same way brick.gdshader's mortar does, because the alternative at this scale is a field of
// moiré that reads as a rendering fault.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 sett_colour : source_color = vec3(0.235, 0.231, 0.220);
// Cinder and clinker: what a boiler house throws out, raked flat and walked on. Grey with the
// warmth knocked out of it — at 0.29/0.27/0.23 under a low sun the whole yard read as sand.
uniform vec3 cinder_colour : source_color = vec3(0.243, 0.235, 0.216);
uniform vec3 grass_colour : source_color = vec3(0.216, 0.239, 0.180);
// Where the setts give out and where the yard does, in metres from the middle of the stack.
uniform float setts_to = 16.0;
uniform float yard_to = 74.0;
uniform float sett_size = 0.145;
// How deep the gaps between the setts are, in metres. Enough to catch a low sun and no more.
uniform float sett_joint = 0.006;

varying vec3 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth noise, and then three octaves of it at an angle.
//
// Per-cell hash on its own is what the first version used, and a square cell of one flat value is
// a tile: a rendered frame of the yard came out as a metre-pitch chequerboard running to the
// horizon, which reads as a texture that failed to load. Interpolating kills the cell edges, and
// rotating each octave by an angle that is not a fraction of a turn stops the three of them
// lining up into a plaid.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ground_noise(vec2 p) {
	const mat2 turn = mat2(vec2(0.86, 0.51), vec2(-0.51, 0.86));
	float n = 0.53 * vnoise(p);
	p = turn * p * 2.17;
	n += 0.30 * vnoise(p);
	p = turn * p * 2.09;
	n += 0.17 * vnoise(p);
	return n;
}

// Setts are laid in fans and arcs, never a grid. Half a stone of offset on alternate rows is the
// cheap version of that and is most of what the eye is actually reading.
vec2 sett_cell(vec2 p) {
	float row = floor(p.y / sett_size);
	return vec2(floor((p.x + mod(row, 2.0) * sett_size * 0.5) / sett_size), row);
}

float sett_relief(vec2 p) {
	float row = floor(p.y / sett_size);
	vec2 in_cell = vec2(fract((p.x + mod(row, 2.0) * sett_size * 0.5) / sett_size),
		fract(p.y / sett_size));
	vec2 to_edge = min(in_cell, 1.0 - in_cell) * sett_size;
	float d = min(to_edge.x, to_edge.y);
	// Crowned, not flat: a sett is a rounded lump, which is why a stone road glints in bands.
	float crown = smoothstep(0.0, sett_size * 0.42, d);
	float n = hash(sett_cell(p));
	return crown * (sett_joint + (n - 0.5) * 0.004);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float d = length(p);

	// How big a pixel is here, in metres. Everything below fades out against it.
	float px = max(max(fwidth(p.x), fwidth(p.y)), 1e-5);

	float to_yard = smoothstep(setts_to, setts_to + 10.0, d);
	float to_field = smoothstep(yard_to, yard_to + 140.0, d);
	// The edges wander. A perfect circle of setts round the chimney is the one thing that would
	// give this away instantly.
	float wobble = (ground_noise(p * 0.035) - 0.5) * 0.55;
	to_yard = clamp(to_yard + wobble, 0.0, 1.0);
	to_field = clamp(to_field + wobble * 0.6, 0.0, 1.0);

	// Setts keep the per-stone hash: a sett IS a flat cell, and the joint between two of them is
	// the thing being drawn. Everything past them is ground rather than masonry, so it gets the
	// smooth noise instead.
	float sett_n = hash(sett_cell(p));
	vec3 setts = sett_colour * (0.78 + 0.44 * sett_n);
	float cinder_n = ground_noise(p * 2.6);
	vec3 cinder = cinder_colour * (0.80 + 0.42 * cinder_n);
	float field_n = ground_noise(p * 0.55);
	// Rough grass over cinder: the value swings a long way, because from the top of a chimney the
	// ground past the wall is patches, not a colour.
	vec3 field = mix(cinder_colour * 0.9, grass_colour, clamp(field_n * 1.5, 0.0, 1.0))
		* (0.82 + 0.34 * ground_noise(p * 3.1));
	// Fade each grain out as its features drop under a pixel, or the whole plane crawls.
	setts = mix(sett_colour, setts, clamp((sett_size - px) / sett_size, 0.0, 1.0));
	cinder = mix(cinder_colour, cinder, clamp((0.38 - px) / 0.38, 0.0, 1.0));
	field = mix(mix(cinder_colour * 0.9, grass_colour, 0.55), field,
		clamp((1.8 - px) / 1.8, 0.0, 1.0));

	vec3 col = mix(mix(setts, cinder, to_yard), field, to_field);

	// The one thing that has to survive distance.
	//
	// Everything above is metre-scale and fades out as its features drop under a pixel, which is
	// correct and which left the view from the cap — the shot the whole game is built towards —
	// as one flat olive plane running to the fog, exactly the fault the town was added to fix.
	// This octave is thirty metres across. It never drops under a pixel from anywhere a player can
	// stand, and it is what turns the ground between the buildings into yards, ash, allotments and
	// cinder tracks instead of a billiard cloth.
	float broad = ground_noise(p * 0.028);
	col *= 0.74 + 0.52 * broad;
	// Darker lanes through it: the gaps between rows, which from above is most of what a mill town
	// actually is.
	float lane = ground_noise(p * 0.075 + vec2(31.7, 11.3));
	col = mix(col, col * 0.62, smoothstep(0.58, 0.78, lane) * to_field);
	// Soot falls out of a chimney onto the ground under it. The darkest ring is not at the wall,
	// it is a little out from it, which is where the draught actually drops it.
	col *= mix(0.84, 1.0, smoothstep(4.0, 30.0, d));

	ALBEDO = col;

	// Relief, only where there are setts and only while they are bigger than a pixel.
	float show = (1.0 - to_yard) * clamp((sett_size - px * 1.5) / sett_size, 0.0, 1.0);
	if (show > 0.001) {
		float e = max(px * 1.2, 0.002);
		float r0 = sett_relief(p);
		vec2 slope = vec2(sett_relief(p + vec2(e, 0.0)) - r0,
			sett_relief(p + vec2(0.0, e)) - r0) / e * show;
		// The plane faces up, so the two tangents are simply x and z.
		vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
		NORMAL = normalize(n * mat3(INV_VIEW_MATRIX));
	}

	ROUGHNESS = mix(0.86, 1.0, to_field);
	SPECULAR = mix(0.28, 0.06, to_yard);
}

// Brick, procedurally — ART-010's core, in text.
//
// The stack was a flat-coloured tube. You cannot read mortar on a surface that has no mortar, and
// reading mortar is the game. So: courses, bricks in running bond, mortar between them, and enough
// per-brick variation that it reads as fired clay rather than as a grid.
//
// A shader rather than a texture because a texture is a binary asset and binary is the half of this
// project agents cannot author or review. The courses come from the level file's own jointGrid
// block — `courseHeight` 75 mm, `brickLength` 225 mm — so the brick you see is the brick the sim
// generated joints for.
//
// Mortar lines fade to the average colour as they get smaller than a pixel. Without that the stack
// shimmers into moiré from twenty metres away, which reads as a rendering fault rather than as
// distance.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 brick_colour : source_color = vec3(0.29, 0.16, 0.11);
uniform vec3 mortar_colour : source_color = vec3(0.46, 0.43, 0.39);
uniform float course_height = 0.075;
uniform float brick_length = 0.225;
uniform float mortar_width = 0.010;
// How much bricks differ from one another. Fired clay is never one colour.
uniform float variation = 0.22;
// Soot and bleach, as the stack weathers top to bottom. See chimney.gd's _weathered().
uniform float stack_height = 55.0;
uniform vec3 soot : source_color = vec3(0.09, 0.08, 0.07);
uniform vec3 bleach : source_color = vec3(0.541, 0.533, 0.506);

// --- relief ------------------------------------------------------------------------------------
// How deep the mortar sits behind the face of the brick, in metres. Victorian work was struck or
// weather-struck: 3 to 6 mm, not the flush pointing on a modern house, which is why raking light
// finds every course on an old stack and finds nothing on a new wall.
uniform float joint_depth = 0.005;
// How far a brick may sit proud of or shy of its neighbours. Hand-laid, over a century, on a stack
// that has moved: this is what stops a wall reading as a printed grid.
uniform float brick_proud = 0.0022;
// The face of a fired brick is not flat, and at arm's length that is most of what you see.
uniform float grain = 0.0009;

varying vec3 world_pos;

float hash(vec2 p) {
	// Stable per-brick noise. Not a random number: the same brick is the same colour every frame
	// and on every machine.
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// The surface, in metres proud of the deepest part of the joint, at a point on the unrolled wall.
//
// One function, sampled three times, rather than an analytic gradient: the field has a floor(),
// a fract() and two hashes in it, and the derivative of that written out by hand is both longer
// and a thing that silently disagrees with the colour the moment either is edited. Three samples
// of a dozen cheap instructions is nothing, and the relief cannot drift away from the brick.
float relief(vec2 p) {
	float course = floor(p.y / course_height);
	float shifted = p.x + mod(course, 2.0) * brick_length * 0.5;
	float brick = floor(shifted / brick_length);

	vec2 in_brick = vec2(fract(shifted / brick_length), fract(p.y / course_height));
	vec2 to_edge = min(in_brick, 1.0 - in_brick) * vec2(brick_length, course_height);
	float d = min(to_edge.x, to_edge.y);

	// Out of the joint and up onto the face over about 4 mm — the arris, which is rounded on
	// anything that has stood in weather and is the reason old brickwork reads soft.
	float face = smoothstep(mortar_width * 0.45, mortar_width * 0.45 + 0.004, d);
	float n = hash(vec2(brick, course));
	float sits = joint_depth + (n - 0.5) * 2.0 * brick_proud;
	// The face itself, pitted. Tied to the brick so it does not crawl across the joint.
	float pit = (hash(floor(p * 420.0) + brick) - 0.5) * 2.0 * grain;
	return face * (sits + pit);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = max(length(world_pos.xz), 0.001);
	// Distance round the stack, in metres. Bearing times radius, so bricks stay brick-sized as the
	// batter narrows the stack towards the top.
	float around = atan(world_pos.x, -world_pos.z) * r;
	float h = world_pos.y;

	float course = floor(h / course_height);
	// Running bond: every other course shifted by half a brick.
	float shifted = around + mod(course, 2.0) * brick_length * 0.5;
	float brick = floor(shifted / brick_length);

	// Where in its brick this pixel is, 0..1 each way.
	vec2 in_brick = vec2(fract(shifted / brick_length), fract(h / course_height));
	// Distance to the nearest mortar line, in metres, each way.
	vec2 to_edge = min(in_brick, 1.0 - in_brick) * vec2(brick_length, course_height);

	// How wide a pixel is here, in metres. When mortar is thinner than that, stop drawing it and
	// blend towards the average instead.
	vec2 px = max(fwidth(vec2(around, h)), vec2(1e-5));
	vec2 line = smoothstep(vec2(mortar_width * 0.5) - px, vec2(mortar_width * 0.5) + px, to_edge);
	float in_mortar = 1.0 - line.x * line.y;
	float resolvable = clamp((mortar_width - max(px.x, px.y)) / mortar_width, 0.0, 1.0);

	float n = hash(vec2(brick, course));
	vec3 fired = brick_colour * (1.0 - variation * 0.5 + variation * n);
	// A little variation along the brick as well, so a face is not a set of flat tiles.
	fired *= 0.94 + 0.06 * hash(vec2(floor(shifted / 0.04), course));

	// The average of brick and mortar by area, for when the lines are too small to draw.
	float mortar_share = mortar_width / course_height + mortar_width / brick_length;
	vec3 average = mix(brick_colour, mortar_colour, mortar_share);

	vec3 near = mix(fired, mortar_colour, in_mortar);
	vec3 col = mix(average, near, resolvable);

	float u = clamp(h / max(stack_height, 1.0), 0.0, 1.0);
	col = mix(col, soot, clamp(1.0 - u / 0.25, 0.0, 1.0) * 0.55);
	col = mix(col, bleach, clamp((u - 0.75) / 0.25, 0.0, 1.0) * 0.30);

	ALBEDO = col;

	// --- the bump ------------------------------------------------------------------------------
	//
	// Perturbed in a basis built here rather than through NORMAL_MAP, because the wall is unrolled
	// by hand: the horizontal axis is distance *around* the stack, which no UV on a tapered
	// cylinder agrees with. Building the two axes from the interpolated normal keeps the relief
	// square to the courses however the mesh underneath happens to be wound.
	vec3 n_world = normalize(NORMAL * mat3(VIEW_MATRIX));
	vec3 around_axis = normalize(cross(vec3(0.0, 1.0, 0.0), n_world) + vec3(1e-5));
	vec3 up_axis = normalize(cross(n_world, around_axis));

	// One sample spacing per pixel, so the bump dissolves at the same rate the mortar does instead
	// of turning into a field of sparkle twenty metres out.
	float e = max(max(px.x, px.y) * 1.2, 0.0012);
	// `around`, not `shifted`: relief() applies the running-bond offset itself, and handing it a
	// coordinate that has already been offset shifts every odd course twice — a bump pattern
	// half a brick out of step with the mortar it is supposed to be lighting.
	vec2 q = vec2(around, h);
	float r0 = relief(q);
	vec2 slope = vec2(relief(q + vec2(e, 0.0)) - r0, relief(q + vec2(0.0, e)) - r0) / e;
	slope *= resolvable;

	vec3 bumped = normalize(n_world - around_axis * slope.x - up_axis * slope.y);
	NORMAL = normalize(bumped * mat3(INV_VIEW_MATRIX));

	// Mortar is recessed and duller than the brick face. A cheap cue, and most of what makes
	// brickwork read as relief rather than as a painted grid under a raking sun.
	ROUGHNESS = mix(0.88, 0.97, in_mortar * resolvable);
	// Damp lime mortar and a hundred years of soot take the sheen off the joints; the fired face
	// keeps a little, which is what catches the sun along a course at a shallow angle.
	SPECULAR = mix(0.36, 0.12, in_mortar * resolvable) * (0.85 + 0.3 * n);
	// Self-shadowing in the joint, deepened by how far this brick sits proud of its neighbours.
	AO = mix(1.0, 0.62, in_mortar * resolvable);
	AO_LIGHT_AFFECT = 0.7;
}

// Cloth, skin and leather on the jack himself.
//
// He is built out of spheres, boxes and tubes, and every one of them carried a flat base colour
// and a single roughness number. That is the ceiling on him: you can add primitives all night —
// and I have, twice — and more lumps will not make a man, because what tells you a sleeve is wool
// is not its silhouette, it is the weave catching light along the arm and going dark across it.
//
// This does not make him photoreal. It is not a sculpt and there are no painted maps. What it
// does is give every surface on him the thing the brickwork already has: a grain, a relief and a
// response to light that varies across the piece.
//
// `kind` picks the treatment:
//   0 CLOTH    woven, with warp and weft and the fuzz that makes wool read as wool
//   1 SKIN     pores, and the mottling of sixty years outdoors
//   2 LEATHER  grain and creases, and a sheen where it has been handled
//   3 PLAIN    the old behaviour, for buttons and iron
//   4 ROPE     three strands laid in a helix, which is the whole look of rope
//   5 HAIR     strands, which is noise combed one way rather than noise in all directions

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.5, 0.5, 0.5);
uniform int kind = 0;
uniform float rough = 0.85;
// Weave pitch in metres. Coarse wool is about 1.5 mm; a shirt is finer.
uniform float weave = 0.0016;
uniform float relief = 0.00035;
// How much light a fabric throws back at grazing angles. This is the whole difference between
// cloth and painted plastic and it costs one dot product.
uniform float sheen = 0.45;

varying vec3 local_pos;
varying vec3 world_normal;

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

// The surface at a point on the piece, as (fine, coarse) — both in units of `relief`.
//
// The split matters. The fine half is at the weave's pitch, a millimetre or two, and it has to be
// faded out before the pixel gets bigger than it or it aliases into a speckle: the first version
// of this shader put him in mud-splattered trousers at three metres, because one fade covered both
// halves and was set three weave-pitches wide — six times too slow — so what reached the screen
// was a weave sampled at well under Nyquist, at two-thirds strength. The coarse half is folds and
// creases at three to ten centimetres, it never aliases, and fading it is what made the cloth go
// flat whenever the grain was retired.
vec2 surface(vec2 p) {
	if (kind == 0) {
		// Warp and weft: two out-of-phase ripples at right angles, which is a plain weave.
		float warp = sin(p.x / weave * 6.2831853);
		float weft = sin(p.y / weave * 6.2831853 + 1.5707963);
		// Cloth is not flat either — it hangs in folds far bigger than its weave.
		float fold = vnoise(p * 34.0) * 0.55 + vnoise(p * 9.0) * 0.45;
		return vec2((warp * weft) * 0.45, fold * 2.2);
	}
	if (kind == 1) {
		// Skin: fine pores over the larger slackness of an old face and old hands.
		return vec2(vnoise(p * 900.0) * 0.5 + vnoise(p * 150.0) * 0.8, vnoise(p * 30.0) * 1.6);
	}
	if (kind == 2) {
		// Leather: a pebbled grain, and creases where it folds.
		float grain = vnoise(p * 420.0);
		float crease = smoothstep(0.62, 0.78, vnoise(p * 26.0));
		return vec2(grain * 0.8, -crease * 2.4);
	}
	if (kind == 4) {
		// Rope. The lay is not decoration: it is the only thing that tells a coil from a hosepipe,
		// and this coil was wearing the plain weave above, at a shirt's pitch.
		// Strands run at about 40 degrees to the rope's axis; `weave` is the lay pitch, so for a
		// 25 mm three-strand hemp it wants roughly 12 mm, not the 1.6 mm a shirt wants.
		float along = dot(p, vec2(0.766, 0.643));
		float lay = sin(along / weave * 6.2831853);
		// Strands are round and the valleys between them are sharp, so the wave is not a sine.
		lay = sign(lay) * pow(abs(lay), 0.55);
		// And hemp is hairy: fibres combed along the strand, not across it.
		float fibre = vnoise(p * vec2(620.0, 130.0));
		return vec2(fibre * 0.7, lay * 2.4);
	}
	if (kind == 5) {
		// Hair, which is strands: noise stretched hard along one axis. Round noise gives a scalp
		// that looks like porridge.
		return vec2(vnoise(p * vec2(70.0, 1100.0)) * 1.3, vnoise(p * vec2(18.0, 260.0)) * 1.0);
	}
	return vec2(0.0);
}

void vertex() {
	local_pos = VERTEX;
	world_normal = NORMAL;
}

void fragment() {
	vec3 col = tint;
	float r = rough;

	if (kind != 3) {
		// Two axes across the surface, built from the normal, so the grain lies on the piece
		// however its triangles happen to be wound — the same trick the brick uses on a tapered
		// cylinder nobody has UV'd.
		vec3 n = normalize(NORMAL * mat3(VIEW_MATRIX));
		vec3 ax = normalize(cross(vec3(0.0, 1.0, 0.0), n) + vec3(1e-5));
		vec3 ay = normalize(cross(n, ax));
		vec2 p = vec2(dot(local_pos, vec3(1.0, 0.0, 0.0)) + local_pos.z * 0.31,
			local_pos.y + local_pos.z * 0.17);

		float pix = max(fwidth(p.x), fwidth(p.y));
		float e = max(pix * 1.2, 0.00008);
		// Nyquist: two samples to a cycle. Start letting the fine half go at a third of the weave
		// pitch and have it gone by two-thirds, well before a pixel can straddle a whole thread.
		float fine = 1.0 - smoothstep(weave * 0.33, weave * 0.66, pix);

		vec2 h0 = surface(p);
		vec2 hx = surface(p + vec2(e, 0.0));
		vec2 hy = surface(p + vec2(0.0, e));
		float s0 = (h0.x * fine + h0.y) * relief;
		vec2 slope = vec2((hx.x * fine + hx.y) * relief - s0,
			(hy.x * fine + hy.y) * relief - s0) / e;
		NORMAL = normalize(normalize(n - ax * slope.x - ay * slope.y) * mat3(INV_VIEW_MATRIX));

		// Colour varies with the relief: thread crowns catch the light, hollows hold the dirt.
		//
		// This has to fade with `fine` and it has to be small. A thread crown is a thread wide, so
		// at any range where a pixel covers several of them the right answer is the flat colour —
		// the crowns have averaged out, which is what a distant garment actually looks like.
		// Carrying it to full strength at every distance, off a clamped fold term that saturated
		// over half the surface, gave a 22% swing in blotches two centimetres across: the dark
		// wool read as mud splatter down his back and the moleskin as grit. It survived every
		// renderer setting I suspected first, because none of them were doing it.
		col *= 1.0 + 0.09 * fine * clamp(h0.x, -1.0, 1.0);

		if (kind == 1) {
			// Weathered: the back of a neck and a pair of hands that have been outside for fifty
			// years are not the colour of a face that has been under a cap.
			col *= 0.92 + 0.16 * vnoise(p * 60.0);
			col = mix(col, col * vec3(1.08, 0.92, 0.88), 0.35);
		}
		// Same rule for roughness: worn patches are real, but they are a close-range thing, and
		// roughness drives the rim, which on a dark garment is the only bright thing there is.
		r = rough + 0.09 * fine * (vnoise(p * 80.0) - 0.5);
	}

	ALBEDO = col;
	ROUGHNESS = clamp(r, 0.05, 1.0);

	if (kind == 0 || kind == 4 || kind == 5) {
		// Fabric sheen. Wool, corduroy, moleskin and hemp all throw light back at the silhouette,
		// and that rim is most of what separates cloth from a painted surface at any distance.
		// Hair does it too, and more sharply, which is why it is the one thing on him that catches
		// a low sun.
		SPECULAR = 0.12;
		RIM = sheen;
		RIM_TINT = 0.35;
	} else if (kind == 1) {
		SPECULAR = 0.28;
	} else if (kind == 2) {
		SPECULAR = 0.34;
	}
}

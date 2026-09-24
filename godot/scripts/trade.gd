# What the job actually is, in the trade's own voice.
#
# The designer played it and said: "There are lots and lots of controls about jigs and all this
# other stuff and bands. None of it made any sense to me." Then, having read this on the board and
# gone up the chimney: **"one has 'The run' and then something about tape? I have no idea what tape
# is or why it's on my screen."**
#
# Which is the whole lesson. Explaining a job on the screen where you accept it is not explaining
# it. By the time he is sixty metres up with a reel in his hand the letter is three screens behind
# him, and the instrument in the corner says "100 m of tape" as if tape were a thing everybody
# knows about. So the note lives here, and BOTH the board and the job itself say it.
#
# Keyed on archetype rather than carried per level, so a level cannot ship without one.

class_name Trade
extends RefCounted

const NOTE := {
	"SURVEY":
		"She has to be read before anyone spends money on her. You climb her, sound every joint "
		+ "you can reach, and chalk what you find. A joint that rings dead is perished mortar "
		+ "behind a sound face — you cannot see it from the ground, and that is the whole reason "
		+ "somebody pays a man to go up.",
	"CONDUCTOR":
		"Lightning earths itself through a chimney whether you help it or not, and if it goes "
		+ "through wet brick the steam blows the shaft apart. A terminal at the apex, copper tape "
		+ "run down her and clipped to holdfasts, and a plate buried in wet ground at the bottom. "
		+ "A run with no earth at the end of it is not protection, it is an attraction.",
	"BAND":
		"Brickwork has nothing holding it together round its girth, so a shaft cracked down its "
		+ "length is a bundle of staves. Steel bands go round her, and the bolts in them are what "
		+ "squeeze — a loose band does nothing at all. Pull them up in opposite pairs, the way you "
		+ "would do wheel nuts. Work round the ring in order instead and she draws in where you "
		+ "have been, stands off where you have not, and goes oval on you.",
	"TOP":
		"She comes down brick by brick, from the top, with you standing on what is left of her. "
		+ "Bolster into the joint, lean on the bar, and let go the instant the mortar gives — hold "
		+ "on a moment past that and you are loading the brick rather than the joint, and it "
		+ "breaks. Sound a joint before you lever it and you will know where it lets go.",
	"FELL":
		"You are not knocking her down, you are choosing which way she falls. Cut a gob out of the "
		+ "base on the side she is to go and prop it with timber as you cut, so she is standing on "
		+ "wood by the end. Then you burn the props. Everything that decides where she lands "
		+ "happened before the fire was lit.",
	"STRAIGHTEN":
		"She is out of plumb and the owner wants her back. You cut a wedge out of the high side, a "
		+ "course at a time, and she settles down into it under her own weight. It is done in "
		+ "millimetres over a day, and there is no putting brick back.",
}


## The one sentence a player needs at the moment the instrument appears, as opposed to the whole
## note. Short enough to sit under a read-out without becoming a wall.
const WHAT_IT_IS := {
	"SURVEY": "sound every joint you can reach and chalk what you find",
	"CONDUCTOR": "copper tape, clipped down her side — the road you are giving the lightning, "
		+ "from a terminal at the top to a plate buried in wet ground",
	"BAND": "steel round her girth. The bolts are what squeeze; a loose band does nothing",
	"TOP": "she comes down a brick at a time, and you are stood on what is left",
	"FELL": "she is going over, and you are choosing which way",
	"STRAIGHTEN": "a wedge out of the high side, and she settles into it",
}


static func note(archetype: String) -> String:
	return String(NOTE.get(archetype, ""))


static func what_it_is(archetype: String) -> String:
	return String(WHAT_IT_IS.get(archetype, ""))

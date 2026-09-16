# IP & Likeness

**Binding on all content work.** Checked at every milestone gate. A blocking item in the Definition
of Done for writing, VO, art and marketing.

## The position

This game is inspired by the **trade of steeplejacking** and by **techniques that are matters of
public record** — driving dogs into mortar joints, lashing ladders, cutting a gob, propping and
firing a chimney, taking a stack down by hand, gilding a weathervane. Techniques, occupations and
historical practices are not protectable, and depicting them is entirely legitimate.

What *is* protected, and what we therefore do not use:

- A real person's **name**, in any form, including in level names, achievement names, file names,
  code comments, commit messages, or marketing copy.
- A real person's **likeness** — face, distinctive appearance, or a character designed to be
  recognisably them.
- A real person's **voice**, delivery, or an impersonation of either.
- **Catchphrases** or distinctive verbal mannerisms associated with a real person.
- Footage, photographs, recordings or **broadcast material**, or anything derived from them.
- The names of real companies, mills, or the specific chimneys they owned.

## Rules

### 1. The character
Original. Give him his own name, his own history, his own voice. He is a Northern English
steeplejack in the 1970s–80s, which describes a real occupation that many real people held.

**Working name:** *Dennis Hartley*. Anyone may propose a better one; nobody may propose a real one.

### 2. The accent
A regional English accent is not a likeness. It is how a large number of people speak. A Lancashire
or West Yorkshire accent is fine; an impression of a specific individual's delivery is not.

Direction for the VO session, which must be in the brief: *"A working Northern steeplejack. Dry,
laconic, fond of masonry. Do not do an impression of anybody."*

### 3. Catchphrases
None. Not as an easter egg, not as an achievement name, not in the credits. The character's warmth
comes from what he notices, not from a repeated line.

### 4. Level and place names
Fictional composites. Use real *geography* freely — Pennine mill towns, canals, the Aire, the
Calder — but invent the specific mills, works, chimneys and streets.

The twelve level names in this design are all invented. Before shipping, **search each one** to
confirm it doesn't match a real industrial chimney that a real person is publicly associated with.
If one does, change it.

### 5. The traction engine
Generic period design. Not a replica of a specific surviving engine, and not carrying a real
preserved machine's name or registration.

### 6. Marketing
Never describe the game with a real person's name — not in the store page, not in a press release,
not in a pitch deck, not in a social post, not in a reply to a comment asking about it.

**If a journalist or a player makes the comparison themselves, that is their observation and we do
not repeat, amplify, quote or retweet it.** Prepared response: *"It's about the steeplejack's trade,
which a lot of people did."*

### 7. Estates
If any real person's estate or representative makes contact, the position is: the game depicts a
historical occupation and its documented techniques, uses no name, likeness, voice or catchphrase,
and we are happy to discuss any specific concern. Escalate to the project lead; do not respond
individually.

## Review checklist (run at every milestone gate)

- [ ] `grep -ri` the repo for any real person's name — code, docs, comments, commit history, asset
      filenames, string tables, VO scripts
- [ ] Character design reviewed against the likeness rule
- [ ] VO script reviewed for catchphrases and distinctive mannerisms
- [ ] Level names searched against real industrial sites
- [ ] Store/marketing copy reviewed
- [ ] No sourced footage, photographs or broadcast material anywhere in the project, including
      reference folders that ship

## A note on research

Using documentary material as **research** — to get the technique right — is normal and fine.
Using it as **reference art that ships**, or transcribing its narration, is not.

Keep research material out of the repository. Put technique notes in your own words in
`docs/01-gdd/`, which is what those documents already are.

# game/ — the presentation layer

Reads `sim/` state, renders it, and sends **intents** back. Makes no gameplay decisions.

A PR that puts a gameplay decision in here will be rejected — see [`../AGENTS.md`](../AGENTS.md).

Scenes are thin: a `.tscn` holds node structure and nothing else. Behaviour is in `.gd`, tuning is in
`data/tuning/`, content is in `data/levels/`.

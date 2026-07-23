class_name SlotSelectFlow
## Tiny cross-screen state for the menu flow. Static-only — no autoload
## needed for four fields.

enum Mode { NEW_GAME, CONTINUE, BOSS_RUSH }

static var mode := Mode.NEW_GAME
static var coop := false
## Armed by slot_select.gd when the player confirms "start new game" on an
## ALREADY-OCCUPIED slot (two-press, mirrors the delete confirm). Consumed
## by character_select.gd's _on_pick(), which resets it immediately — every
## menu entry point also resets it defensively so it can never leak into an
## unrelated later flow (same class of bug `coop` had before it was fixed).
static var force_new := false

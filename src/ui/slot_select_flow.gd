class_name SlotSelectFlow
## Tiny cross-screen state for the menu flow. Static-only — no autoload
## needed for three fields.

enum Mode { NEW_GAME, CONTINUE, BOSS_RUSH }

static var mode := Mode.NEW_GAME
static var coop := false

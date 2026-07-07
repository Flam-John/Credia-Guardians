class_name SlotSelectFlow
## Tiny cross-screen state for the menu flow (which mode slot-select is in).
## Static-only — no autoload needed for two fields.

enum Mode { NEW_GAME, CONTINUE }

static var mode := Mode.NEW_GAME

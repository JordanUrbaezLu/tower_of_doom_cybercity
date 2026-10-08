// _tod_toast.gsh — the HUD toast ids (v19.58, the map-wide typography pass).
//
// Server text drawn by IPrintLnBold is always in the engine font, so the map's
// own notices ride tod_upgrade_ui::toast() instead: an int-only LuiNotifyEvent
// (&"tod_toast", 3, id, a, b) and the Lua in tod_upgrade.lua sets the words in
// the map's typeface. The words live in ONE place, the Lua TOAST table.
// LOCKSTEP: every id here is a row in that table (a and b fill {A} / {B}).
#define TOD_TOAST_TIER_AT_FLOOR      1   // CLASS TIER {A} UNLOCKS AT FLOOR {B}
#define TOD_TOAST_FLOOR_TIER         2   // FLOOR {A} REACHED - CLASS TIER {B} UNLOCKED
#define TOD_TOAST_FLOOR_TIER_PAP     3   // ... + PACK-A-PUNCH TO PROMOTE
#define TOD_TOAST_NEW_WEAPONS        4   // NEW WEAPONS ARE NOT PACK-A-PUNCHED
#define TOD_TOAST_PERK_SLOTS_FULL    5   // PERK SLOTS FULL
#define TOD_TOAST_HOLD_THE_HALL      6   // HOLD THE HALL
#define TOD_TOAST_TRIAL_WON          7   // THE TRIAL IS WON - THE WAY IS OPEN
#define TOD_TOAST_MAGE_HINT          8   // HEALING AURA BLINK AND ARCHMAGE / UNLOCK WITH THEIR UPGRADE CARDS
#define TOD_TOAST_CRATE_NOTHING      9   // NOTHING TO REFILL / STAFFS AND BLADES NEVER RUN DRY
#define TOD_TOAST_CRATE_FULL        10   // AMMO ALREADY FULL
#define TOD_TOAST_TRIAL_SEALED      11   // THE TRIAL BELOW IS NOT WON / WIN IT TO CLIMB (v19.76: a skip attempt sent back to the hall)

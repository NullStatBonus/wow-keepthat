# Proposal

## Why

The loot toast is silent, so a player who looks away misses it. Issue #15 asked for an optional sound. The default should be one every player recognizes and that both clients already contain, so nothing is downloaded or bundled.

## What Changes

- When the loot toast is on, a new toast plays a sound. The default is the game's auction house opening sound (sound kit 5274, 2.2 seconds).
- Appearance > Loot toast gains a **Sound** picker: None, ten built-in game sounds (Auction open, Level up, Quest complete, Ready check, Raid warning, PvP queue ready, Murloc aggro, Bell toll (Alliance), Bell toll (Horde), Battle.net toast), plus sounds from LibSharedMedia-3.0 when another addon provides that library.
- Appearance > Loot toast gains a **Sound channel** picker: Master (default) or Sound effects.
- Choosing a sound plays it once, so the player can hear it.
- A loot burst plays one sound. A short cooldown stops the next pickups from repeating it; adding to an existing toast's count is silent.
- A saved sound that cannot play here (sound pack uninstalled, library gone) falls back to the default, never raises an error.
- KeepThat ships no sound files and does not bundle LibSharedMedia.

Out of scope: a toast font choice (also in #15). The toast keeps the game font; no one has asked for a font choice.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `loot-toast`: adds the toast sound: when it plays, the cooldown, the fallback, and None.
- `settings`: Appearance owns the sound and channel pickers; the defaults gain Auction open and Master.

## Impact

- New `Model/Sounds.lua` (the built-in list plus resolving a choice to something playable; plain Lua) and `Core/Adapter_Sound.lua` (`PlaySound`, `PlaySoundFile`, the LibSharedMedia lookup), added to both TOC files.
- `UI/Toast.lua` plays the sound when a new toast is queued.
- `Core/Defaults.lua`: `toastSound` and `toastSoundChannel`.
- `Options/Options.lua`: two dropdowns in the Loot toast group.
- Locale strings, tests (`test_sounds.lua`, `test_toast.lua`, `test_options.lua`), README, listing, test plan, `docs/contracts.md` (sound kit IDs verified on both builds).
- Version: minor bump at archive (new feature).

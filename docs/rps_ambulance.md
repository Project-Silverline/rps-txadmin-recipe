# rps_ambulance

Death, respawn and a basic ambulance job for `rps_core`.

## Install

Add after rps_core in `server.cfg`:

```
ensure oxmysql
ensure ox_lib
ensure rps_core
ensure ox_inventory
ensure illenium-appearance
ensure rps_ambulance
```

No SQL needed. Death state is stored in rps_core's character metadata (`isDead`).

## How it works

**Dying** puts the player into a downed state where they stay in place with a death
animation (or slumped in their seat if they were in a vehicle). Movement and combat
are disabled; chat, voice and looking around still work.

- `G` sends one distress call per death to every online EMS (notification + map blip).
- After `Config.RespawnTime` seconds, `E` respawns them at the hospital for `Config.RespawnFee`.
- Logging out or disconnecting while downed keeps them downed when they come back,
  and the timer restarts, so combat-logging doesn't skip it.

**EMS** (job `ambulance`, set with `/setjob <id> ambulance <grade>`):

| Command | Effect |
|---|---|
| `/revive` | CPR on the closest downed player, pays `Config.ReviveReward` |
| `/heal` | Restores the closest conscious player's health |

**Hospital check-in**: injured (not downed) players can pay to heal at the marker,
only when no EMS are online by default (`Config.CheckIn.maxEms`).

**Admin**: `/adrevive [id]` revives or heals a player, or yourself.

Every action is validated on the server: job, distance, and whether the target is
actually downed. Respawn is checked against a server-side timer.

## With ox_inventory

ox_inventory is optional. When it's running:

- `/revive` (or using a **medkit** from the inventory) consumes one medkit, and `/heal`
  consumes one **bandage**. Items are only taken when the action succeeds.
  Set `Config.Items.revive` / `heal` to `nil` to remove the requirement.
- Medics get an **EMS locker** (personal by default) and an **EMS supplies** shop at the
  hospital. Positions are in `Config.Locker` and `Config.Supply`.
- Downed players can't open their inventory or use items.
- `Config.ClearInventoryOnRespawn` wipes the inventory on hospital respawn, keeping the
  items in `Config.KeepOnRespawn` (cash by default).

See `install/SETUP_ox_inventory.md` for setting up ox_inventory itself.

## For other resources

```lua
-- server
exports.rps_ambulance:IsDead(source)
exports.rps_ambulance:Revive(source)

-- client / anywhere
exports.rps_ambulance:IsDead()      -- client, local player
Player(serverId).state.isDead        -- any player, state bag
```

## Before going live

The hospital coordinates in `config.lua` point at Central Los Santos Medical Center.
Check them in-game, especially if you use a hospital MLO, and move the respawn
point and check-in marker to match.

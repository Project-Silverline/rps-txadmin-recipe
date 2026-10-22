# illenium-appearance for RPS

illenium-appearance gives every character a saved look: new characters design theirs
before they first play, and clothing stores, barbers, tattoo parlours, plastic surgeons
and saved outfits work out of the box. Like ox_inventory, it only supports frameworks
it ships with, so the `rps` bridge files go inside it, plus one small edit. **Updating
illenium-appearance overwrites both, so redo steps 2 and 3 after every update.**

Checked against illenium-appearance at commit 1b003ec (November 2024).

## 1. Install illenium-appearance

Download the latest **release** from
https://github.com/iLLeniumStudios/illenium-appearance/releases
(the release zip includes the built web UI; the source code download does not).
Keep the folder name `illenium-appearance`: rps_core checks for that exact name.

## 2. Add the bridge

Copy both folders from this package into illenium-appearance:

```
install/illenium-appearance/client/framework/rps/main.lua → illenium-appearance/client/framework/rps/main.lua
install/illenium-appearance/server/framework/rps/main.lua → illenium-appearance/server/framework/rps/main.lua
```

## 3. Register the bridge files

Open `illenium-appearance/fxmanifest.lua` and add one line in each list, right after
the `ox` lines:

```lua
client_scripts {
  ...
  "client/framework/ox/main.lua",
  "client/framework/rps/main.lua",      -- add
  ...
}

server_scripts {
  ...
  "server/framework/ox/main.lua",
  "server/framework/rps/main.lua",      -- add
  ...
}
```

## 4. Database

Run `install/sql/migrations/002_appearance.sql` (fresh installs: `install/sql/install.sql`
already includes it). illenium-appearance doesn't create its tables itself.

## 5. server.cfg

illenium-appearance starts after rps_core:

```
ensure oxmysql
ensure ox_lib
ensure rps_core
ensure ox_inventory
ensure illenium-appearance
ensure rps_ambulance
```

## 6. Optional: EMS changing room

illenium-appearance already has ambulance job outfits in `Config.Outfits`. To let medics
change into them at the hospital, add this entry to `Config.ClothingRooms` in
`illenium-appearance/shared/config.lua`, next to the existing police one. The position is
beside the EMS locker; check it in-game.

```lua
    {
        job = "ambulance",
        coords = vector4(334.0, -1402.5, 32.5, 50.0),
        size = vector3(3, 3, 3),
        rotation = 50,
        usePoly = false,
    },
```

## How it works with RPS

- **New characters** spawn with the screen faded out, then the appearance editor opens.
  It can't be closed until the character's look is saved.
- **Returning characters** get their saved look applied before the screen fades in, so
  the default ped is never shown.
- **Shops charge cash** through rps_core. With ox_inventory, that's the `money` item.
- **Jobs** are passed in as illenium-appearance expects, so job outfits and job-locked
  clothing rooms work for `police` and `ambulance`. Gangs aren't used.
- **`/pedmenu`** (any ped model) is limited to `group.admin`, which matches RPS groups.
- **Deleting a character** removes its saved skins and outfits.

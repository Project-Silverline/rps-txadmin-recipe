# RPS Framework – Install

```
RPS_Framework/
  [rps]/                         ← copy this whole folder into your server's resources folder
    rps_core/
    rps_ambulance/
  install/                       ← setup files and documentation (not a resource)
    README.md                      this file
    RPS_Framework_Documentation.md full reference
    rps_core.md                    rps_core quick reference
    rps_ambulance.md               rps_ambulance quick reference
    SETUP_ox_inventory.md          inventory setup
    SETUP_illenium-appearance.md   appearance and clothing setup
    server.cfg.example
    sql/install.sql                fresh install
    sql/migrations/                updates for existing databases
    ox_inventory/                  bridge files to copy into ox_inventory
    illenium-appearance/           bridge files to copy into illenium-appearance
```

## Requirements

FiveM server with OneSync enabled, MySQL or MariaDB, and these resources:
[oxmysql](https://github.com/overextended/oxmysql/releases),
[ox_lib](https://github.com/overextended/ox_lib/releases),
[ox_inventory](https://github.com/overextended/ox_inventory/releases),
[illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance/releases).
Download the release zips, not the source code.

## Steps

1. **Database.** Fresh install: run `sql/install.sql`.
   Existing RPS database: run each file in `sql/migrations/` you haven't run yet.
2. **Resources.** Copy the `[rps]` folder into your `resources` folder. Keep the folder
   names exactly as they are, because exports are called by resource name.
3. **ox_inventory.** Follow `SETUP_ox_inventory.md`: copy the bridge, make the one edit in
   `modules/mysql/server.lua`, and add the `medkit` item.
4. **illenium-appearance.** Follow `SETUP_illenium-appearance.md`: copy the bridge and add
   two lines to its `fxmanifest.lua`.
5. **server.cfg.** Add the lines from `server.cfg.example`, including the `add_ace resource.ox_lib` lines (groups and admin commands don't work without them). Keep the start order:
   oxmysql, ox_lib, rps_core, ox_inventory, illenium-appearance, rps_ambulance. Remove any other framework
   (ESX, QBCore, Qbox).
6. **Admin.** Join once, then in the server console run `setgroup <your server id> admin`.
7. **Check positions in-game.** The hospital respawn, check-in, EMS locker and supply shop
   coordinates in `rps_ambulance/config.lua` and the selection camera in
   `rps_core/shared/config.lua` are untested defaults.

After updating ox_inventory or illenium-appearance, redo step 3 or 4: updates overwrite
the bridge and the edit.

Full reference: `RPS_Framework_Documentation.md`.

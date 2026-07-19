# Free Your Destiny (Freeyd)

An open source emulator for the **With Your Destiny 7.54** game server. Written in **Zig**, with **Lua** used to script the server logic — making it easy to add and maintain game behavior without recompiling the server.

---

## Implemented Features

| Feature | Status |
|---|---|
| Login | ✅ |
| Create account (auto sign-up on first login) | ✅ |
| PIN password | ✅ |
| Create character | ✅ |
| Delete character | ✅ |
| Spawn character (enter world) | ✅ |
| Player movement broadcast | ✅ |
| Map teleport portals | ✅ |
| Manual teleport (GM command) | ✅ |
| Receive chat message | ✅ |
| Whisper / command system | ✅ |
| Mob spawn (NPCs visible on world entry) | ✅ |
| Disconnect / session cleanup | ✅ |
| Move item / inventory swap | ❌ |
| Public chat broadcast | ❌ |
| Attack / combat | ❌ |

---

## How it works

`main.zig` is the entry point. It parses CLI arguments (`--host`, `--port`), registers OS signal handlers (SIGINT/SIGTERM for graceful shutdown), initializes the database, the Lua runtime, and the TCP server, then wires them together through `ServerLogic`. Once running, it loops until a shutdown signal is received.

---

## Project Structure

### `src/core` — Domain Entities

Shared data structures used across all modules. Serves as the common language between the network layer, database, and Lua bindings.

- **`Account`** — user account: username, password, state (online/offline), gold, cargo slots, and up to 4 characters.
- **`Character`** — player character: class, level, equipment slots, position (x/y), city/citizen info, and soul type.
- **`Item`** — item: ID and attribute/effect list.
- **`Mob`** — NPC or monster: ID, name, stats, skill attributes, resistances, buffers, and equipment slots.
- **`World`** (`world.zig`) — tracks mobs currently in the world using a `QuadTree` for spatial indexing. Exposes `createMob`, `moveMob`, and `listMobInArea` for area-based queries (e.g. "find all mobs within range of a player").

---

### `src/db` — Data Persistence

Defines a vtable-based interface (`Database`) so the rest of the project does not depend on a specific storage backend. Any implementation that satisfies the interface can be swapped in.

**Interface operations:**
- `login` — authenticate a user.
- `signup` — register a new account.
- `updateAccount` — persist account changes.
- `getAccountByUsername` — look up an account by name.

**Current implementation:** `filedb` — stores each account as a binary file in the `dbs/` directory. Suitable for development and lightweight deployments. Additional backends (SQLite, PostgreSQL, etc.) can be added by implementing the same `VTable`.

---

### `src/lua` — Lua Runtime & Bindings

Integrates the Lua C API into Zig and exposes all domain types and server operations to Lua scripts.

- **`wrapper.zig`** — a full-featured Zig wrapper around the C Lua API. Provides a `State` struct with helpers for pushing/popping values, calling functions, managing the registry, creating metatables, and handling userdata.
- **`bindings/`** — one binding file per domain type, each exposing its struct as a Lua userdata with methods:
  - `account_binding.zig` — `Account` methods (e.g. `save`, field access).
  - `character_binding.zig` — `Character` methods.
  - `item_binding.zig` — `Item` methods.
  - `mob_binding.zig` — `Mob` methods.
  - `database_binding.zig` — database operations callable from Lua (`get_account_by_username`, `create_account`, etc.).
  - `packet_binding.zig` — exposes incoming packet data (e.g. `req.username`, `req.password`) to Lua event handlers.
  - `world_binding.zig` — exposes world operations (mob creation, area queries) to Lua.
  - `peer/` — exposes the connected peer to Lua (`peer:send_text(...)`, `peer:associate(account)`, `peer:send_command(...)`).

---

### `src/network` — Networking

Handles all TCP communication with game clients.

- **`server.zig`** — listens on a configurable address (default `0.0.0.0:8281`), manages a pool of up to 100 concurrent `Peer` slots, and accepts connections concurrently.
- **`peer.zig`** — represents a single client connection. Validates a handshake init code on connection, then continuously reads and decodes packets, forwarding each to `ServerLogic`. Manages a state machine: `Accepted → Logged → Playing → Disconnected`.
- **`packet/`** — packet protocol layer: typed input/output structs for all known game opcodes, encryption/decryption, and packet builder helpers.

---

### `src/serverlogic` — Server Logic Bridge

Connects the network layer to the Lua scripting engine.

- **`serverlogic.zig`** — on startup: registers all Lua bindings, seeds initial world mobs, and loads all scripts from `./scripts/`. At runtime: receives every incoming packet and forwards it to the `Dispatcher`.
- **`loader.zig`** — recursively walks `./scripts/` and loads every `.lua` file into the Lua state.
- **`dispatcher.zig`** — maps packet opcodes to Lua event names (e.g. `login → "on_login"`, `chatMessage → "on_chat_message"`). Calls the matching Lua function with `(peer, packet)` on each packet. Fires `"on_disconnected"` on client drop.
- **`server_binding/`** — exposes a `server` global to Lua. `server:on(event, fn)` registers handlers; `server:get_database()`, `server:get_world()`, `server:get_peer(id)` provide access to server resources.

---

### `src/utils` — Utilities

- **`quadtree/`** — a generic `QuadTree(T, capacity)` spatial index. Nodes subdivide automatically when full. Supports `insert`, `remove`, and rect-based area queries. Used by `World` to track mob positions efficiently.
- **`parsearg/`** — a generic CLI argument parser for `--key value` style flags. Used at startup to configure `--host` and `--port`.

---

## Scripts (`scripts/`)

Game logic lives here as Lua files, loaded automatically on startup. Scripts register event handlers via `server:on(eventName, fn)`.

| File | Event |
|---|---|
| `on_login.lua` | Authenticates or registers the player, sets account state, sends the client into the account screen. |
| `on_disconnected.lua` | Sets account to `OFFLINE` and saves state on client disconnect. |
| `on_pinpassword.lua` | Creates PIN on first use; validates on subsequent logins. |
| `character_events/on_create_char.lua` | Creates character with class-based starter equipment, position, stats, and skills. |
| `character_events/on_delete_char.lua` | Validates password and name, then deletes the character slot. |
| `character_events/on_spawn_char.lua` | Enters the world: sends spawn packet, loads nearby mobs, notifies other players. |
| `mob_events/on_mob_motion.lua` | Updates player position in the QuadTree and broadcasts movement to other players. |
| `mob_events/on_teleport.lua` | Checks if player stepped on a portal coordinate and teleports them to the destination. |
| `chat/on_chat_message.lua` | Receives public chat (logs only; broadcast not yet implemented). |
| `chat/on_chat_whisper.lua` | Whisper-based command system: `time`, `tp x y`, `tab`, `help`. |

---

## Lua Type Definitions (`lua_types/`)

Contains `.lua` annotation files (`account.lua`, `character.lua`, `database.lua`, `item.lua`, `mob.lua`, `world.lua`, etc.) for IDE autocompletion and type checking of the Lua scripting API.

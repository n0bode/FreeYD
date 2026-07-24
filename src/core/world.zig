const std = @import("std");
const Allocator = std.mem.Allocator;
const domains = @import("domains/domains.zig");
const MobQuadTree = @import("core.zig").MobQuadTree;

pub const SpawnedMob = MobQuadTree.Point;
const Position = domains.Position;
const Item = domains.Item;
const Mob = domains.Mob;
const NPC = domains.NPC;

const MAX_PLAYERS = 1000;

pub const SpawnedNPC = struct {
    npc: NPC,
    fnUpdate: i32,
    fnInteract: i32,
    spawnedMob: SpawnedMob,
};

pub const CreateNPC = struct {
    name: []const u8,
    position: Position,
    onUpdate: i32,
    onInteract: i32,
    equipments: [16]Item,
};

pub const World = struct {
    arena: std.heap.ArenaAllocator,

    npcs: std.ArrayList(SpawnedNPC),
    mobs: std.ArrayList(Mob),
    treeMobs: MobQuadTree,
    maxPlayers: usize,

    pub fn init(child_allocator: Allocator, maxPlayers: usize) !World {
        var self: World = undefined;
        self.arena = std.heap.ArenaAllocator.init(child_allocator);
        const allocator = self.arena.allocator();

        self.maxPlayers = maxPlayers;
        // map size
        self.treeMobs = MobQuadTree.init(allocator, 4096);
        // init with 1000 mobs
        // important: more mobs, needs heap invoke commands
        self.mobs = try .initCapacity(allocator, 1000);
        self.npcs = try .initCapacity(allocator, 100);
        return self;
    }

    pub fn deinit(self: World) void {
        self.arena.deinit();
    }

    pub fn moveMob(self: *World, x: i16, y: i16, mobSpawned: *SpawnedMob) !*SpawnedMob {
        // remove last position
        _ = mobSpawned.remove();

        mobSpawned.x = x;
        mobSpawned.y = y;
        if (!try self.treeMobs.insert(mobSpawned)) {
            return error.MobOutOfMap;
        }
        return mobSpawned;
    }

    pub fn createNPC(self: *World, info: CreateNPC) !*SpawnedNPC {
        const index = self.npcs.items.len;
        var npc: SpawnedNPC = undefined;

        var mobBase = Mob{};
        @memcpy(mobBase.name[0..info.name.len], info.name[0..]);
        for (info.equipments, 0..) |item, i| {
            if (i == 14) {
                mobBase.equipments[i] = .fromMount(item);
            } else {
                mobBase.equipments[i] = .from(item);
            }
        }

        const mob = try self.createMob(&mobBase);
        const position = info.position;

        mob.stats.state.merchant = 1;
        npc.npc.id = mob.mobId;
        npc.npc.mob = mob;
        npc.npc.startPosition = position;
        npc.npc.currentPosition = npc.npc.startPosition;
        npc.npc.updatedAt = 0;

        @memset(npc.npc.name[0..], 0);
        @memcpy(npc.npc.name[0..info.name.len], info.name[0..]);

        npc.fnInteract = info.onInteract;
        npc.fnUpdate = info.onUpdate;
        npc.spawnedMob = .{ .x = position.x, .y = position.y, .data = mob };

        self.npcs.appendAssumeCapacity(npc);
        const ptr = &self.npcs.items[index];
        if (!try self.treeMobs.insert(&ptr.spawnedMob)) {
            _ = self.npcs.pop();
            return error.MobOutOfMap;
        }
        return ptr;
    }

    pub fn createMob(self: *World, mobBase: *Mob) !*Mob {
        self.mobs.appendAssumeCapacity(mobBase.*);
        const index = self.mobs.items.len - 1;
        const mob = &self.mobs.items[index];
        mob.mobId = @as(u16, @intCast(index)) + @as(u16, @intCast(self.maxPlayers));
        return mob;
    }

    pub fn createMobSpawned(self: *World, mobBase: *Mob, x: i16, y: i16) !*SpawnedMob {
        const allocator = self.arena.allocator();

        const mob = try self.createMob(mobBase);

        var mobSpawned = try allocator.create(SpawnedMob);
        mobSpawned.x = x;
        mobSpawned.y = y;
        mobSpawned.data = mob;

        if (!try self.treeMobs.insert(mobSpawned)) {
            allocator.destroy(mobSpawned);
            return error.MobOutOfMap;
        }
        return mobSpawned;
    }

    /// allocate um result array with mob found
    pub fn listMobInAreaAlloc(self: *World, allocator: Allocator, x: i16, y: i16, w: u16, h: u16) ![]*MobQuadTree.Point {
        const rect = MobQuadTree.Rect{
            .x = @intCast(x),
            .y = @intCast(y),
            .width = @intCast(w),
            .height = @intCast(h),
        };
        return self.treeMobs.listInAreaAlloc(allocator, rect);
    }
};

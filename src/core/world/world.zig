const std = @import("std");
const entity = @import("entity.zig");
const core = @import("../core.zig");
const domains = core.domains;

const WorldTree = core.WorldTree;
const Allocator = std.mem.Allocator;

pub const Spawned = entity.Spawned;
const Point = core.Point;
const Position = domains.Position;
const Item = domains.Item;
const GroundItem = domains.GroundItem;
const Mob = domains.Mob;
const NPC = domains.NPC;

const MAX_PLAYERS = 1000;

const logger = std.log.scoped(.world);

pub const CreateNPC = struct {
    name: []const u8,
    position: Position,
    tick: u32,
    onUpdate: i32,
    onInteract: i32,
    equipments: [16]Item,
};

pub const CreateEnemy = struct {
    name: []const u8,
    position: Position,
    tick: u32,
    delay: u32,
    onUpdate: i32,
    onDeath: ?i32,
    onInteract: ?i32,
    stats: domains.Stats,
    equipments: [16]Item,
};

pub const CreateItem = struct {
    item: Item,
    position: Position,
    rotation: u8,
    state: u8,
    onInteract: i32,
};

pub const World = struct {
    arena: std.heap.ArenaAllocator,

    mobs: std.heap.MemoryPool(Mob),
    items: std.ArrayList(GroundItem),
    points: std.heap.MemoryPool(Spawned),
    indexes: std.AutoHashMap(u16, *Spawned),

    tree: WorldTree,

    maxPlayers: u16,
    maxMobs: u16,
    maxItems: u16,

    countMobs: std.atomic.Value(u16),
    countItems: std.atomic.Value(u16),

    pub fn init(
        child_allocator: Allocator,
        maxPlayers: u16,
        maxMobs: u16,
        maxItems: u16,
    ) !World {
        var self: World = undefined;
        self.arena = std.heap.ArenaAllocator.init(child_allocator);

        const itemIndex, var overflow = @addWithOverflow(maxPlayers, maxMobs);
        if (overflow == 1) {
            return error.MaxPlayersAndMobsOverflow;
        }

        _, overflow = @addWithOverflow(itemIndex, maxItems);
        if (overflow == 1) {
            return error.MaxPlayersAndMobsOverflow;
        }

        self.indexes = .init(child_allocator);
        // map size
        self.tree = .init(child_allocator, 4096);
        // init with 1000 mobs
        // important: more mobs, needs heap invoke commands
        self.mobs = try .initCapacity(child_allocator, maxMobs);
        self.items = try .initCapacity(child_allocator, maxItems);
        self.points = try .initCapacity(child_allocator, maxMobs);

        self.countMobs = .init(maxPlayers);
        self.countItems = .init(itemIndex);

        self.maxPlayers = maxPlayers;
        self.maxItems = maxItems;
        self.maxMobs = maxMobs;
        return self;
    }

    pub fn deinit(self: World) void {
        self.arena.deinit();
    }

    pub fn getPosition(self: *World, id: u16) !Position {
        const ptr = self.indexes.getPtr(id) orelse {
            return error.MobNotFound;
        };
        return Position{
            .x = ptr.point.x,
            .y = ptr.point.y,
        };
    }

    pub fn remove(self: *World, id: u16) !void {
        const point = self.indexes.get(id) orelse {
            return error.MobNotFound;
        };

        // remove last position
        _ = point.point.remove();
        self.points.destroy(point);
    }

    pub fn move(self: *World, id: u16, x: i16, y: i16) !void {
        const ptr = self.indexes.get(id) orelse {
            return error.MobNotFound;
        };

        const point = &ptr.point;
        // remove last position
        _ = point.remove();
        point.x = x;
        point.y = y;

        if (!try self.tree.insert(point)) {
            return error.MobOutOfMap;
        }
    }

    pub fn getGroundItem(self: *World, id: u16) !*GroundItem {
        const obj = self.indexes.get(id) orelse return error.ItemNotFound;
        return switch (obj.entity) {
            .item => |item| item,
            else => error.NotAnItem,
        };
    }

    pub fn get(self: *World, id: u16) !*Spawned {
        return self.indexes.get(id) orelse {
            return error.MobNotFound;
        };
    }

    pub fn createNPC(self: *World, info: CreateNPC) !*Spawned {
        var mobBase = Mob{};
        @memcpy(mobBase.name[0..info.name.len], info.name[0..]);
        for (info.equipments, 0..) |item, i| {
            if (i == 14) {
                mobBase.equipments[i] = .fromMount(item);
            } else {
                mobBase.equipments[i] = .from(item);
            }
        }

        const allocator = self.arena.allocator();
        const mob = try self.mobAlloc(allocator, &mobBase, true);
        errdefer self.mobs.destroy(@alignCast(mob));

        const spawned = try self.points.create(allocator);
        errdefer self.points.destroy(spawned);

        const position = info.position;
        spawned.* = .{
            .startPosition = .{ .x = position.x, .y = position.y },
            .onInteract = info.onInteract,
            .onUpdate = info.onUpdate,
            .tick = info.tick,
            .entity = .{ .mob = mob },
            .point = .{ .x = position.x, .y = position.y },
        };

        // must be 1 to interact with npc

        const len = @min(info.name.len, mob.name.len);
        @memset(mob.name[0..], 0);
        @memcpy(mob.name[0..len], info.name[0..len]);

        try self.indexes.put(mob.mobId, spawned);
        if (!try self.tree.insert(&spawned.point)) {
            return error.MobOutOfMap;
        }
        return spawned;
    }

    pub fn createEnemy(self: *World, info: CreateEnemy) !*Spawned {
        var mobBase = Mob{
            .stats = info.stats,
        };
        for (info.equipments, 0..) |item, i| {
            if (i == 14) {
                mobBase.equipments[i] = .fromMount(item);
            } else {
                mobBase.equipments[i] = .from(item);
            }
        }

        const allocator = self.arena.allocator();
        const mob = try self.mobAlloc(allocator, &mobBase, true);
        errdefer self.mobs.destroy(@alignCast(mob));

        const spawned = try self.points.create(allocator);
        errdefer self.points.destroy(spawned);

        const position = info.position;
        spawned.* = .{
            .startPosition = .{ .x = position.x, .y = position.y },
            .onUpdate = info.onUpdate,
            .onDeath = info.onDeath,
            .onInteract = info.onInteract,
            .countTick = info.delay,
            .tick = info.tick,
            .entity = .{ .mob = mob },
            .point = .{ .x = position.x, .y = position.y },
        };

        const len = @min(info.name.len, mob.name.len);
        @memset(mob.name[0..], 0);
        @memcpy(mob.name[0..len], info.name[0..len]);

        try self.indexes.put(mob.mobId, spawned);
        if (!try self.tree.insert(&spawned.point)) {
            return error.MobOutOfMap;
        }
        return spawned;
    }

    fn mobAlloc(self: *World, allocator: Allocator, mobBase: *Mob, generateId: bool) !*Mob {
        const mob = self.mobs.create(allocator) catch |err| {
            logger.err("failed to allocate mob: {s}", .{@errorName(err)});
            return err;
        };

        mob.* = mobBase.*;
        if (generateId)
            mob.mobId = self.countMobs.fetchAdd(1, .monotonic);
        return mob;
    }

    pub fn spawnMobWithId(self: *World, mobBase: *Mob, id: u16, x: i16, y: i16) !*Spawned {
        const allocator = self.arena.allocator();
        const mob = try self.mobAlloc(allocator, mobBase, false);
        mob.mobId = id;

        const point = try self.points.create(self.arena.allocator());
        point.* = .{
            .startPosition = .{ .x = x, .y = y },
            .entity = .{ .mob = mob },
            .point = .{ .x = x, .y = y },
        };

        try self.indexes.put(mob.mobId, point);
        if (!try self.tree.insert(&point.point)) {
            _ = self.indexes.remove(mob.mobId);
            return error.MobOutOfMap;
        }
        return point;
    }

    pub fn spawnMob(self: *World, mobBase: *Mob, x: i16, y: i16) !*Spawned {
        const allocator = self.arena.allocator();
        const mob = try self.mobAlloc(allocator, mobBase, true);

        const point = try self.points.create(allocator);
        errdefer self.points.destroy(point);

        point.* = .{
            .startPosition = .{ .x = x, .y = y },
            .entity = .{ .mob = mob },
            .point = .{ .x = x, .y = y },
        };

        if (!try self.tree.insert(&point.point)) {
            _ = self.indexes.remove(mob.mobId);
            return error.MobOutOfMap;
        }
        return point;
    }

    pub fn spawnItem(self: *World, info: CreateItem) !*Spawned {
        const storedItem = try self.items.addOne(self.arena.allocator());
        storedItem.* = .{
            .itemId = 10_000 + @as(u16, @intCast(self.items.items.len)),
            .item = info.item,
            .position = .{ .x = info.position.x, .y = info.position.y },
            .rotation = info.rotation,
            .state = info.state,
            .onInteract = info.onInteract,
        };

        const point = try self.points.create(self.arena.allocator());
        point.* = Spawned{
            .startPosition = .{ .x = info.position.x, .y = info.position.y },
            .entity = .{
                .item = storedItem,
            },
            .point = .{ .x = info.position.x, .y = info.position.y },
        };

        try self.indexes.put(storedItem.itemId, point);

        if (!try self.tree.insert(&point.point)) {
            return error.ItemOutOfMap;
        }
        return point;
    }

    /// allocate um result array with mob found
    pub fn listMobInAreaAlloc(self: *World, allocator: Allocator, x: i16, y: i16, w: u16, h: u16) ![]*Point {
        const rect = WorldTree.Rect{
            .x = @intCast(x),
            .y = @intCast(y),
            .width = @intCast(w),
            .height = @intCast(h),
        };
        return self.tree.listInAreaAlloc(allocator, rect);
    }
};

const std = @import("std");
const entity = @import("entity.zig");
const core = @import("../core.zig");
const domains = core.domains;

const WorldTree = core.WorldTree;
const Allocator = std.mem.Allocator;

pub const Object = entity.Object;
const Point = core.Point;
const Position = domains.Position;
const Item = domains.Item;
const GroundItem = domains.GroundItem;
const Mob = domains.Mob;
const NPC = domains.NPC;

const MAX_PLAYERS = 1000;

pub const CreateNPC = struct {
    name: []const u8,
    position: Position,
    onUpdate: i32,
    onInteract: i32,
    equipments: [16]Item,
};

pub const CreateItem = struct {
    item: Item,
    position: Position,
    rotation: u8,
    state: u8,
};

pub const World = struct {
    arena: std.heap.ArenaAllocator,

    npcs: std.ArrayList(NPC),
    mobs: std.ArrayList(Mob),
    items: std.ArrayList(GroundItem),
    points: std.heap.MemoryPool(Object),
    indexes: std.AutoHashMap(u16, *Object),

    tree: WorldTree,
    maxPlayers: usize,

    pub fn init(child_allocator: Allocator, maxPlayers: usize) !World {
        var self: World = undefined;
        self.arena = std.heap.ArenaAllocator.init(child_allocator);

        self.indexes = .init(child_allocator);
        self.maxPlayers = maxPlayers;
        // map size
        self.tree = .init(child_allocator, 4096);
        // init with 1000 mobs
        // important: more mobs, needs heap invoke commands
        self.mobs = try .initCapacity(child_allocator, 1000);
        self.items = try .initCapacity(child_allocator, 100);
        self.npcs = try .initCapacity(child_allocator, 100);
        self.points = try .initCapacity(child_allocator, 1000);
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

    pub fn get(self: *World, id: u16) !*Object {
        return self.indexes.get(id) orelse {
            return error.MobNotFound;
        };
    }

    pub fn createNPC(self: *World, info: CreateNPC) !*NPC {
        var mobBase = Mob{};
        @memcpy(mobBase.name[0..info.name.len], info.name[0..]);
        for (info.equipments, 0..) |item, i| {
            if (i == 14) {
                mobBase.equipments[i] = .fromMount(item);
            } else {
                mobBase.equipments[i] = .from(item);
            }
        }

        const mob = try self.mobAlloc(&mobBase);
        const position = info.position;

        var npc: NPC = undefined;
        mob.stats.state.merchant = 1;
        npc.id = mob.mobId;
        npc.mob = mob;
        npc.startPosition = position;
        npc.currentPosition = position;
        npc.updatedAt = 0;
        npc.regOnUpdate = info.onUpdate;
        npc.regOnInteract = info.onInteract;

        @memset(npc.name[0..], 0);
        @memcpy(npc.name[0..info.name.len], info.name[0..]);

        self.npcs.appendAssumeCapacity(npc);
        const pNPC = &self.npcs.items[self.npcs.items.len - 1];

        const point = try self.points.create(self.arena.allocator());
        point.* = .{
            .entity = .{ .npc = pNPC },
            .point = .{ .x = position.x, .y = position.y },
        };

        try self.indexes.put(mob.mobId, point);
        std.log.info("ptr {X}", .{@intFromPtr(point)});
        if (!try self.tree.insert(&point.point)) {
            _ = self.npcs.pop();
            return error.MobOutOfMap;
        }
        return pNPC;
    }

    pub fn mobAlloc(self: *World, mobBase: *Mob) !*Mob {
        //mutex?
        const index = self.mobs.items.len;
        self.mobs.appendAssumeCapacity(mobBase.*);

        const mob = &self.mobs.items[index];
        mob.mobId = @as(u16, @intCast(index)) + @as(u16, @intCast(self.maxPlayers));
        return mob;
    }

    pub fn spawnMobWithId(self: *World, mobBase: *Mob, id: u16, x: i16, y: i16) !*Object {
        const mob = try self.mobAlloc(mobBase);
        mob.mobId = id;

        const point = try self.points.create(self.arena.allocator());
        point.* = .{
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

    pub fn spawnMob(self: *World, mobBase: *Mob, x: i16, y: i16) !*Object {
        const mob = try self.mobAlloc(mobBase);

        const point = try self.points.create(self.arena.allocator());
        point.* = .{
            .entity = .{ .mob = mob },
            .point = .{ .x = x, .y = y },
        };

        if (!try self.tree.insert(&point.point)) {
            _ = self.indexes.remove(mob.mobId);
            return error.MobOutOfMap;
        }
        return point;
    }

    pub fn spawnItem(self: *World, info: CreateItem) !*Object {
        const storedItem = try self.items.addOne(self.arena.allocator());
        storedItem.* = .{
            .itemId = 10_000 + @as(u16, @intCast(self.items.items.len)),
            .item = info.item,
            .position = .{ .x = info.position.x, .y = info.position.y },
            .rotation = info.rotation,
            .state = info.state,
        };

        const point = try self.points.create(self.arena.allocator());
        point.* = Object{
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

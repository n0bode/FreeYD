const Mapper = @import("utils.zig").MapperStructPtr;
const bindFunction = @import("utils.zig").bindFunctions;
const domain = @import("binding.zig").domain;
const lua = @import("binding.zig").lua;

const mapper = Mapper(domain.Item);

pub const ItemBinding = @This();

pub const metatableName = mapper.metatableName;

const AttributeBinding = Mapper(domain.ItemAttribute);

pub fn toUserdata(L: *lua.State, idx: i32) ?*domain.Item {
    // TODO: accept table too
    return mapper.toUserdata(L, idx);
}

pub fn newUserdata(L: *lua.State, item: *domain.Item) void {
    const ptr = L.newUserdata(*domain.Item);
    ptr.* = item;
    L.getMetatableByName(metatableName);
    _ = L.setMetatable(-2);
}

pub fn getMetatable(L: *lua.State) void {
    L.getMetatableByName(metatableName);
}

pub fn bind(L: *lua.State) void {
    mapper.bind(L);
    bindFunction(L, metatableName, &.{
        .{
            .name = "new",
            .value = .{ .func = .{ .func = lua__new } },
        },
    });
    AttributeBinding.bind(L);

    mapper.getMetatable(L);
    L.setGlobal("Item");

    AttributeBinding.getMetatable(L);
    L.setGlobal("ItemAttribute");
}

fn lua__new(L: *lua.State) i32 {
    const args: usize = @intCast(L.getTop());
    // heap

    const itemId = L.checkInteger(u16, 1);
    var item = domain.Item{
        .itemID = @intCast(itemId),
    };

    const until = @min(item.attributes.len, args);
    for (1..until) |i| {
        const idx: i32 = @intCast(i + 1);

        L.checkType(idx, .Table);
        L.getField(idx, "index");
        item.attributes[i - 1].index = @intCast(L.checkInteger(u8, -1));
        L.pop(1);

        L.getField(idx, "value");
        item.attributes[i - 1].value = @intCast(L.checkInteger(u8, -1));
        L.pop(1);
    }

    const ptr: *domain.Item = L.newUserdata(domain.Item);
    ptr.* = item;
    ItemBinding.newUserdata(L, ptr);
    return 1;
}

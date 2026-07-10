const State = @import("binding.zig").lua.State;
const network = @import("binding.zig").network;
const std = @import("std");

const Peer = network.Peer;

const Account = @import("binding.zig").domain.Account;
const AccountBinding = @import("binding.zig").AccountBinding;

const Indexer = @import("utils.zig").IndexerField;
pub const PeerBinding = @This();

pub const metatableName = "mt_" ++ @typeName(network.Peer);

pub fn getMetatable(L: *State) void {
    L.getMetatableByName(metatableName);
}

pub fn newUserdata(L: *State, peer: *Peer) void {
    const ptr = L.newUserdata(*Peer);
    ptr.* = peer;

    getMetatable(L);
    _ = L.setMetatable(-2);
}

pub fn bind(L: *State) void {
    _ = L.newMetatable(metatableName);
    L.setFuncs(&.{
        .{
            .name = "send_text",
            .value = .{
                .func = .{
                    .func = lua_send_text,
                },
            },
        },
        .{
            .name = "disconnect",
            .value = .{
                .func = .{
                    .func = lua_disconnect,
                },
            },
        },
        .{
            .name = "associate",
            .value = .{
                .func = .{
                    .func = lua_associate_account,
                },
            },
        },
    });
    L.pushFunction(lua__index);
    L.setField(-2, "__index");
}

fn lua_send_text(L: *State) i32 {
    const peer: *Peer = (L.toUserdata(*Peer, 1) orelse {
        return 0;
    }).*;

    L.checkType(-1, .String);
    const message = L.toString(-1);

    peer.sendTextMessage(message) catch {
        return 0;
    };
    return 0;
}

fn lua_associate_account(L: *State) i32 {
    const peer: *Peer = (L.toUserdata(*Peer, 1) orelse {
        return 0;
    }).*;

    L.checkType(-1, .Userdata);
    const acc = AccountBinding.toUserdata(L, -1) orelse {
        return 0;
    };
    peer.setAccount(acc.*);
    return 0;
}

fn lua_disconnect(L: *State) i32 {
    const peer: *Peer = (L.toUserdata(*Peer, 1) orelse return {
        return 0;
    }).*;
    peer.disconnect();
    return 0;
}

fn lua__index(L: *State) i32 {
    const keyName = L.toString(2);

    _ = L.getMetatable(1);
    L.getField(-1, keyName);
    if (!L.isNil(-1)) {
        return 1;
    }
    L.pop(2);

    const peer: *Peer = (L.toUserdata(*Peer, 1) orelse return {
        L.pushNil();
        return 1;
    }).*;

    if (!Indexer(Peer).pushValue(peer, keyName, L)) {
        L.pushNil();
    }
    return 1;
}

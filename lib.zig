pub const Error = error{
    Warning,
    DebugWarning,
    Unspecified,
    NoDevicesFound,
    InvalidDevice,
    MemoryError,
    InvalidParameter,
    InvalidUse,
    DriverError,
    SystemError,
    ThreadError,
};

const rtmidi = @This();

pub fn openPort(dev: anytype, number: usize, name: [:0]const u8) void {
    c.rtmidi_open_port(cast(dev), @intCast(number), name.ptr);
}

pub fn openVirtualPort(dev: anytype, name: [:0]const u8) void {
    c.rtmidi_open_virtual_port(cast(dev), name.ptr);
}

pub fn closePort(dev: anytype) void {
    c.rtmidi_close_port(cast(dev));
}

pub fn getPortCount(dev: anytype) usize {
    return c.rtmidi_get_port_count(cast(dev));
}

pub fn getPortNameAlloc(dev: anytype, allocator: std.mem.Allocator, number: usize) (std.mem.Allocator.Error || Error)![]u8 {
    var len: c_int = undefined;
    const err = c.rtmidi_get_port_name(cast(dev), @intCast(number), null, &len);
    try unwrap(dev, err);
    const buf = try allocator.alloc(u8, @intCast(len));
    errdefer allocator.free(buf);
    const err2 = c.rtmidi_get_port_name(dev, @intCast(number), buf.ptr, &len);
    try unwrap(dev, err2);
    return buf;
}

pub fn getPortName(dev: anytype, number: usize, buf: []u8) Error!void {
    var len: c_int = @intCast(buf.len);
    const err = c.rtmidi_get_port_name(cast(dev), @intCast(number), buf.ptr, &len);
    try unwrap(dev, err);
}

/// both In and Out pointers may be safely cast to point to this struct type
pub const Dev = extern struct {
    ptr: ?*anyopaque,
    data: ?*anyopaque,
    ok: bool,
    msg: ?[*:0]const u8,
};

pub const Out = opaque {
    pub const openPort = rtmidi.openPort;
    pub const openVirtualPort = rtmidi.openVirtualPort;
    pub const closePort = rtmidi.closePort;
    pub const getPortCount = rtmidi.getPortCount;
    pub const getPortName = rtmidi.getPortName;
    pub const getPortNameAlloc = rtmidi.getPortNameAlloc;

    pub fn createDefault() ?*Out {
        return @ptrCast(c.rtmidi_out_create_default() orelse return null);
    }

    pub fn create(api: Api, name: [:0]const u8) ?*Out {
        return @ptrCast(c.rtmidi_out_create(api, name.ptr) orelse return null);
    }

    pub fn destroy(dev: *Out) void {
        c.rtmidi_out_free(cast(dev));
    }

    pub fn sendMessage(dev: *Out, msg: []const u8) Error!void {
        const err = c.rtmidi_out_send_message(cast(dev), msg.ptr, @intCast(msg.len));
        try unwrap(dev, err);
    }
};

pub const In = opaque {
    pub const openPort = rtmidi.openPort;
    pub const openVirtualPort = rtmidi.openVirtualPort;
    pub const closePort = rtmidi.closePort;
    pub const getPortCount = rtmidi.getPortCount;
    pub const getPortName = rtmidi.getPortName;
    pub const getPortNameAlloc = rtmidi.getPortNameAlloc;

    pub fn createDefault() ?*In {
        return @ptrCast(c.rtmidi_in_create_default() orelse return null);
    }

    pub fn create(api: Api, name: [:0]const u8, queue_size_limit: usize) ?*In {
        return @ptrCast(c.rtmidi_in_create(api, name.ptr, @intCast(queue_size_limit)) orelse return null);
    }

    pub fn destroy(dev: *In) void {
        return c.rtmidi_in_free(cast(dev));
    }

    pub fn setCallback(dev: *In, comptime callback: fn (f64, []const u8, ?*anyopaque) void, user_data: ?*anyopaque) void {
        const inner = struct {
            fn f(delta: f64, msg: ?[*]const u8, size: usize, ctx: ?*anyopaque) callconv(.C) void {
                @call(.always_inline, callback, .{
                    delta, if (msg) |ptr| ptr[0..size] else &.{}, ctx,
                });
            }
        };
        c.rtmidi_in_set_callback(cast(dev), inner.f, user_data);
    }

    pub fn cancelCallback(dev: *In) void {
        c.rtmidi_in_cancel_callback(cast(dev));
    }

    pub fn ignoreTypes(dev: *In, sysex: bool, time: bool, sense: bool) void {
        c.rtmidi_in_ignore_types(cast(dev), sysex, time, sense);
    }

    /// it is recommended to use a buffer of size 1024
    pub fn getMessage(dev: *In, buf: []u8) f64 {
        var len: usize = buf.len;
        return c.rtmidi_in_get_message(cast(dev), buf.ptr, &len);
    }

    pub fn getMessageSize(dev: *In) usize {
        var size: usize = undefined;
        _ = c.rtmidi_in_get_message(cast(dev), null, &size);
        return size;
    }
};

inline fn cast(dev: anytype) *Dev {
    return @ptrCast(@alignCast(dev));
}

fn unwrap(dev: anytype, err: c_int) Error!void {
    const device = cast(dev);
    if (device.ok) return;
    const err_enum: c.Err = @enumFromInt(err);
    switch (err_enum) {
        .warning => {
            if (device.msg) |m| logger.warn("{s}", .{m});
            return error.Warning;
        },
        .debug_warning => {
            if (device.msg) |m| logger.debug("{s}", .{m});
            return error.DebugWarning;
        },
        .unspecified => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.Unspecified;
        },
        .no_devices_found => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.NoDevicesFound;
        },
        .invalid_device => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.InvalidDevice;
        },
        .memory_error => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.MemoryError;
        },
        .invalid_parameter => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.InvalidParameter;
        },
        .invalid_use => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.InvalidUse;
        },
        .driver_error => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.DriverError;
        },
        .system_error => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.SystemError;
        },
        .thread_error => {
            if (device.msg) |m| logger.err("{s}", .{m});
            return error.ThreadError;
        },
    }
}

test {
    const out = Out.createDefault() orelse return error.TestFailed;
    defer out.destroy();
    const in = In.createDefault() orelse return error.TestFailed;
    defer in.destroy();
    in.openVirtualPort("test");
    defer in.closePort();
    out.openVirtualPort("test");
    defer out.closePort();
}

test "ref" {
    std.testing.refAllDeclsRecursive(@This());
}

pub const c = @import("c.zig");
pub const Api = c.Api;
const logger = std.log.scoped(.rtmidi);
const std = @import("std");

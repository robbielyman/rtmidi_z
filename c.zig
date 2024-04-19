pub const CCallback = fn (f64, ?[*]const u8, usize, ?*anyopaque) callconv(.C) void;

pub const Api = enum(c_int) { unspecified, macosx_core, linux_alsa, unix_jack, windows_mm, rtmidi_dummy, web_midi_api, windows_uwp, android, num };

pub const Err = enum(c_int) {
    warning,
    debug_warning,
    unspecified,
    no_devices_found,
    invalid_device,
    memory_error,
    invalid_parameter,
    invalid_use,
    driver_error,
    system_error,
    thread_error,
};

pub extern "c" fn rtmidi_get_version() [*:0]const u8;
pub extern "c" fn rtdmidi_get_compiled_api(apis: ?[*]Api, size: c_uint) c_int;
pub extern "c" fn rtmidi_api_name(api: Api) [*:0]const u8;
pub extern "c" fn rtmidi_api_display_name(api: Api) [*:0]const u8;
pub extern "c" fn rtmidi_compiled_api_by_name(name: [*:0]const u8) Api;
pub extern "c" fn rtmidi_open_port(device: *rtmidi.Dev, port_number: c_uint, name: [*:0]const u8) void;
pub extern "c" fn rtmidi_open_virtual_port(device: *rtmidi.Dev, name: [*:0]const u8) void;
pub extern "c" fn rtmidi_close_port(device: *rtmidi.Dev) void;
pub extern "c" fn rtmidi_get_port_count(device: *rtmidi.Dev) c_uint;
pub extern "c" fn rtmidi_get_port_name(device: *rtmidi.Dev, number: c_uint, buf: ?[*]u8, buf_len: *c_int) c_int;
pub extern "c" fn rtmidi_in_create_default() ?*rtmidi.Dev;
pub extern "c" fn rtmidi_in_create(api: Api, name: ?[*:0]const u8, queue_size_limit: c_uint) ?*rtmidi.Dev;
pub extern "c" fn rtmidi_in_free(dev: *rtmidi.Dev) void;
pub extern "c" fn rtmidi_in_get_current_api(dev: *rtmidi.Dev) Api;
pub extern "c" fn rtmidi_in_set_callback(dev: *rtmidi.Dev, callback: *const CCallback, userdata: ?*anyopaque) void;
pub extern "c" fn rtmidi_in_cancel_callback(dev: *rtmidi.Dev) void;
pub extern "c" fn rtmidi_in_ignore_types(dev: *rtmidi.Dev, sysex: bool, time: bool, sense: bool) void;
pub extern "c" fn rtmidi_in_get_message(dev: *rtmidi.Dev, buf: ?[*]u8, size: *usize) f64;

pub extern "c" fn rtmidi_out_create_default() ?*rtmidi.Dev;
pub extern "c" fn rtmidi_out_create(api: Api, name: ?[*:0]const u8) ?*rtmidi.Dev;
pub extern "c" fn rtmidi_out_free(dev: *rtmidi.Dev) void;
pub extern "c" fn rtmidi_out_send_message(dev: *rtmidi.Dev, msg: [*]const u8, len: c_int) c_int;
pub extern "c" fn rtmidi_out_get_current_api(dev: *rtmidi.Dev) Api;

const rtmidi = @import("lib.zig");

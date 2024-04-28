const std = @import("std");
const arbor = @import("arbor");
const param = arbor.param;
const log = arbor.log;

const Distortion = @This();

export const plugin_desc = arbor.createFormatDescription(.{
    .id = "com.ArborealAudio.ZigVerb",
    .name = "Example Distortion",
    .company = "Arboreal Audio",
    .version = "0.1",
    .url = "https://arborealaudio.com",
    .contact = "contact@arborealaudio.com",
    .manual = "https://manuals.arborealaudio.com/Distortion",
    .description = "Basic distortion plugin",
});

const Mode = enum {
    Vintage,
    Modern,
    Apocalypse,
};

const plugin_params = &[_]arbor.Parameter{
    param.create("Gain", .{ 1.0, 30.0, 1.0 }),
    param.create("Out", .{ 0.0, 12.0, 1.0 }),
    // TODO: Read enum fields by default. Passing a list of choices should be optional
    param.create("Mode", .{ Mode.Vintage, &.{ "Vintage", "Modern", "Apocalypse" } }),
};

some_data: i32,

export fn init() *arbor.Plugin {
    const allocator = std.heap.c_allocator;
    const plugin = arbor.init(allocator, plugin_params);
    // create a user plugin since we have some data of our own
    const user_plugin = allocator.create(Distortion) catch |e|
        log.fatal("Plugin create failed: {}\n", .{e});
    user_plugin.* = .{ // initialize
        .some_data = 42,
    };
    plugin.user = user_plugin; // set the pointer

    return plugin;
}

export fn deinit(plugin: *arbor.Plugin) void {
    // Free your plugin if we set one
    if (plugin.user) |p| {
        const self: *Distortion = @alignCast(@ptrCast(p));
        plugin.allocator.destroy(self);
    }
    // Deinit the outer plugin like this
    arbor.deinit(plugin);
}

export fn prepare(plugin: *arbor.Plugin, sample_rate: f32, max_num_frames: u32) void {
    _ = plugin;
    _ = sample_rate;
    _ = max_num_frames;
}

export fn process(plugin: *arbor.Plugin, buffer: arbor.AudioBuffer(f32)) void {
    const in_gain = plugin.getParamValue(f32, "Gain");
    const out_gain = plugin.getParamValue(f32, "Out");
    const mode = plugin.getParamValue(Mode, "Mode");

    const self = arbor.cast(*Distortion, plugin.user);
    std.debug.assert(self.some_data + 1 == 43);

    for (buffer.input[0..buffer.num_ch], 0..) |ch, ch_idx| {
        for (ch[0..buffer.num_samples], 0..) |sample, idx| {
            switch (mode) {
                .Modern => {
                    buffer.output[ch_idx][idx] = std.math.tanh(in_gain * sample) * out_gain;
                },
                .Vintage => {
                    var x = sample;
                    x *= in_gain;
                    if (x > 0) {
                        x = @min(1, x);
                        x = (3 / 2) * (x - (x * x * x) / 3);
                    } else x = (3 / 2) * std.math.tanh(x);
                    x *= out_gain;
                    buffer.output[ch_idx][idx] = x;
                },
                .Apocalypse => {
                    buffer.output[ch_idx][idx] = @abs(sample);
                },
            }
        }
    }
}
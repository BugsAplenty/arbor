const std = @import("std");
const arbor = @import("arbor");
const param = arbor.param;
const log = arbor.log;

const Distortion = @This();

const Mode = enum {
    Vintage,
    Modern,
    Apocalypse,
};

const plugin_params = &[_]arbor.Parameter{
    param.create("Gain", .{ 1.0, 30.0, 1.0 }),
    param.create("Out", .{ 0.0, 2.0, 1.0 }),
    // TODO: Read enum fields by default. Passing a list of choices should be optional
    param.create("Mode", .{ Mode.Vintage, &.{ "Vintage", "Modern", "Apocalypse" } }),
};

const allocator = std.heap.c_allocator;

export fn init() *arbor.Plugin {
    const plugin = arbor.init(allocator, plugin_params, .{
        .deinit = deinit,
        .prepare = prepare,
        .process = process,
    });
    return plugin;
}

fn deinit(plugin: *arbor.Plugin) void {
    // Free your plugin if we set one
    if (plugin.user) |p| {
        const self = arbor.cast(*Distortion, p);
        plugin.allocator.destroy(self);
    }
    // Deinit the outer plugin like this
    arbor.deinit(plugin);
}

fn prepare(plugin: *arbor.Plugin, sample_rate: f32, max_num_frames: u32) void {
    _ = plugin;
    _ = sample_rate;
    _ = max_num_frames;
}

fn process(plugin: *arbor.Plugin, buffer: arbor.AudioBuffer(f32)) void {
    const in_gain = plugin.getParamValue(f32, "Gain");
    const out_gain = plugin.getParamValue(f32, "Out");
    const mode = plugin.getParamValue(Mode, "Mode");

    const start = buffer.offset;
    const end = buffer.offset + buffer.frames;

    for (buffer.input[0..buffer.num_ch], 0..) |ch, ch_idx| {
        var out = buffer.output[ch_idx];
        for (ch[start..end], start..) |sample, idx| {
            // For performance reasons, you wouldn't want to branch inside
            // this loop, but...example
            switch (mode) {
                .Modern => {
                    out[idx] = (3.0 / 2.0) * std.math.tanh(in_gain * sample) * out_gain;
                },
                .Vintage => {
                    var x = sample;
                    x *= in_gain;
                    if (x > 0) {
                        x = @min(1, x);
                        x = (3.0 / 2.0) * (x - (x * x * x) / 3.0);
                    } else x = (3.0 / 2.0) * std.math.tanh(x);
                    x *= out_gain;
                    out[idx] = x;
                },
                .Apocalypse => {
                    var x = sample;
                    x *= in_gain;
                    x = @abs(x);
                    x *= out_gain;
                    out[idx] = x;
                },
            }
        }
    }
}

const draw = arbor.Gui.draw;

pub const WIDTH = 500;
pub const HEIGHT = 600;
const background_color = draw.Color{ .r = 0, .g = 0x80, .b = 0x80, .a = 0xff };
const border_color = draw.Color{ .r = 0xc0, .g = 0xf0, .b = 0xc0, .a = 0xff };

// Export an entry to our GUI implementation
export fn gui_init(plugin: *arbor.Plugin) void {
    const gui = arbor.Gui.init(allocator, .{
        .plugin = plugin,
        .width = WIDTH,
        .height = HEIGHT,
        .interface = .{
            .deinit = gui_deinit,
            .render = gui_render,
        },
    });
    plugin.gui = gui;

    // TODO: Allow the user to describe layout in more relative terms rather
    // than computing based on window size, etc.
    // somehting like getNextLayoutSection() and it will provide a rect which corresponds
    // to the appropriate area based on a layout chosen *prior* to instantiating components
    const comp_width = (WIDTH / plugin_params.len) / 2;
    const gap = WIDTH / 8;
    // create pointers, assign IDs and values
    // this is how the components get "attached" to parameters
    // setup unique properties here
    for (0..plugin_params.len) |i| {
        const param_info = plugin.getParamId(@intCast(i)) catch |e| {
            log.err("{}\n", .{e});
            return;
        };
        if (!std.mem.eql(u8, param_info.name, "Mode")) {
            gui.addComponent(arbor.Gui.Slider.init(&.{
                .canvas = gui.canvas,
                .interface = arbor.Gui.Slider.interface,
                .value = param_info.getNormalizedValue(plugin.params[i]),
                .pos = .{
                    .x = @floatFromInt(i * comp_width + gap * (i + 1)),
                    .y = HEIGHT / 2 - 100,
                },
                .width = @as(f32, @floatFromInt(comp_width)),
                .height = 200,
                .background_color = draw.Color{ .r = 0, .g = 0x70, .b = 0x70, .a = 0xff },
                .label = .{
                    .text = param_info.name,
                    .height = 18,
                    .color = draw.Color{ .a = 0xff, .r = 0xff, .g = 0xff, .b = 0xff },
                    .border = draw.Color{ .a = 0xff, .r = 0xcc, .g = 0xcc, .b = 0xcc },
                    .flags = .{
                        .border = true,
                        .center_x = true,
                        .center_y = false,
                    },
                },
            }).*);
        } else { // mode menu
            gui.addComponent(.{
                .canvas = gui.canvas,
                .interface = arbor.Gui.Menu.interface,
                .value = plugin.params[i], // don't bother normalizing since we just care about the int
                .pos = .{
                    .x = @floatFromInt(i * comp_width + gap * (i + 1)),
                    .y = HEIGHT / 2 - 50,
                },
                .width = @as(f32, @floatFromInt(comp_width)) * 1.5,
                .height = 100,
                .background_color = draw.Color.NULL,
                .label = .{
                    .text = param_info.name,
                    .height = 18,
                    .color = draw.Color.WHITE,
                },
                .sub_type = .{ .menu = .{
                    .choices = param_info.enum_choices orelse {
                        log.err("No enum choices available\n", .{});
                        return;
                    },
                    .border_color = draw.Color.WHITE,
                    .border_thickness = 3,
                } },
            });
        }
    }
}

fn gui_deinit(gui: *arbor.Gui) void {
    _ = gui;
}

fn gui_render(gui: *arbor.Gui) void {
    draw.olivec_fill(gui.canvas, background_color.toBits());
    draw.olivec_frame(gui.canvas, 2, 2, WIDTH - 4, HEIGHT - 4, 4, border_color.toBits());

    for (gui.components.items) |*c| {
        c.interface.draw_proc(c);
    }
}

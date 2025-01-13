// plugin.zig
// Audio Generation Module for Zynth Synthesizer

const std = @import("std");
const arbor = @import("arbor");
const libVoicePool = @import("VoicePool");
const libOscillator = @import("oscillator");
const log = arbor.log;
const param = arbor.param;
const dsp = arbor.dsp;

const Zynth = @This();

const plugin_params = &[_]arbor.Parameter{
};

const allocator = std.heap.c_allocator;
    /// Deinitialize the Plugin
export fn init() *arbor.Plugin {
    const plugin = arbor.init(allocator, plugin_params, .{
        .deinit = deinit,
        .prepare = prepare,
        .process = process,
    });
    try plugin.voice_pool.init(allocator, 8, 44100.0, Waveform.Sine);
    return plugin;
}
fn deinit(plugin: *arbor.Plugin) void {
    _ = plugin;
    // If we set user data in init(), you would free it here
}
fn prepare(plugin: *arbor.Plugin, sample_rate: f32, max_num_frames: u32) void {
    plugin.sample_rate = sample_rate;
    plugin.max_frames = max_num_frames;
}
/// Process audio frames
pub fn process(plugin: *arbor.Plugin, buffer: arbor.AudioBuffer(f32)) void {
    // Retrieve Parameter Values
    const out_gain_db = plugin.getParamValue(f32, "Out");
    const out_gain = dbToLinear(out_gain_db);

    // Iterate over each frame to generate and write audio samples
    for (0..buffer.frames) |frame| {
        var sample: f32 = 0.0;

        // Iterate over each voice in the voice pool
        for (plugin.voice_pool.voices) |*voice| {
            // Generate audio sample for voice
            sample += voice.generate_sample();
        }

        // Apply output gain
        sample *= out_gain;

        // Write sample to each channel
        for (0..buffer.num_ch) |channel| {
            buffer.output[channel][frame] = sample;
        }
    }
}

/// Convert dB to Linear Gain
fn dbToLinear(db: f32) f32 {
    return std.math.pow(f32, 10.0, db * 0.05);
}

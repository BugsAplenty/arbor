const std = @import("std");
const math = std.math;

pub fn midiToFrequency(note: u8) f32 {
    return 440.0 * math.pow(2.0, (f32(note) - 69.0) / 12.0);
}

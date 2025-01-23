// oscillator.zig
// Oscillator Module for Zynth Synthesizer

const std = @import("std");
const math = std.math;

/// Defines the available waveform types for the oscillator
pub const Waveform = enum {
    Sine,
    Square,
    Sawtooth,
    Triangle,
    Pulse,
    Noise, // For adding noise (optional)
};

/// Oscillator Struct
pub const Oscillator = struct {
    waveform: Waveform,
    frequency: f32,
    sample_rate: f32,
    phase: f32,
    phase_increment: f32,
    rng: std.rand.DefaultPrng, // persistent RNG for Noise

    /// Initialize the Oscillator
    /// - Follows the "pointer + !void" style of filter.zig
    pub fn init(self: *Oscillator, sample_rate: f32, waveform: Waveform) !void {
        // 1) Basic state
        self.waveform = waveform;
        self.frequency = 440.0; // default freq (A4)
        self.sample_rate = sample_rate;
        self.phase = 0.0;
        self.phase_increment = (2.0 * math.pi * self.frequency) / self.sample_rate;

        // 2) Initialize RNG (noise path) - might fail in some Zig versions
        // so we do `try` for safety
        self.rng = std.rand.DefaultPrng.init(12345);
    }

    /// (Optional) Deinitialize the Oscillator
    pub fn deinit(self: *Oscillator) void {
        // If you needed to free something or close a file handle, do it here.
        // For an inline rng and some floats, there's nothing to free.
        _ = self;
    }

    /// Set the Oscillator's frequency
    pub fn set_frequency(self: *Oscillator, frequency: f32) void {
        self.frequency = frequency;
        self.phase_increment = (2.0 * math.pi * self.frequency) / self.sample_rate;
    }

    /// Generate a single sample based on the current waveform and phase
    pub fn generate_sample(self: *Oscillator) f32 {
        var sample: f32 = 0.0;

        switch (self.waveform) {
            .Sine => {
                sample = math.sin(self.phase);
            },
            .Square => {
                sample = if (self.phase < math.pi) 1.0 else -1.0;
            },
            .Sawtooth => {
                sample = (2.0 * (self.phase / (2.0 * math.pi))) - 1.0;
            },
            .Triangle => {
                sample = 2.0 * @abs(2.0 * (self.phase / (2.0 * math.pi)) - 1.0) - 1.0;
            },
            .Pulse => {
                // Pulse width of 50% (can be parameterized)
                const pulse_width = 0.5;
                sample = if (self.phase < (2.0 * math.pi * pulse_width)) 1.0 else -1.0;
            },
            .Noise => {
                // Generate white noise using the persistent RNG
                // In your Noise case:
                var rng = std.rand.DefaultPrng.init(12345);
                sample = rng.random().float(f32);
            },
        }

        // Increment phase
        self.phase += self.phase_increment;
        if (self.phase >= 2.0 * math.pi) {
            self.phase -= 2.0 * math.pi;
        }

        return sample;
    }

    /// Reset the Oscillator's phase (useful when starting a new note)
    pub fn reset_phase(self: *Oscillator) void {
        self.phase = 0.0;
    }
};

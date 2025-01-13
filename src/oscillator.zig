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

    /// Initialize the Oscillator
    pub fn init(self: *Oscillator, waveform: Waveform, frequency: f32, sample_rate: f32) void {
        self.waveform = waveform;
        self.frequency = frequency;
        self.sample_rate = sample_rate;
        self.phase = 0.0;
        self.phase_increment = (2.0 * math.pi * self.frequency) / self.sample_rate;
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
                // Generate white noise
                sample = std.rand.DefaultPrng.init(std.rand.default_seed()).nextFloat() * 2.0 - 1.0;
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

// voice_pool.zig
// Voice Pool Module for Zynth Synthesizer

const std = @import("std");
const math = std.math;
const allocator = std.heap.page_allocator;
const libOscillator = @import("oscillator.zig");
const Oscillator = libOscillator.Oscillator;
const Waveform = libOscillator.Waveform;

const log = @import("arbor.zig").log;

/// Voice Struct
pub const Voice = struct {
    isActive: bool = false,
    note: u8 = 0,
    velocity: u8 = 0,
    channel: u8 = 0,
    sample_rate: f32 = 44100.0,
    amplitude: f32 = 0.0,
    oscillator: Oscillator,

    /// Initialize the Voice
    pub fn init(self: *Voice, sample_rate: f32, waveform: Oscillator.Waveform) !void {
        self.isActive = false;
        self.note = 0;
        self.velocity = 0;
        self.channel = 0;
        self.sample_rate = sample_rate;
        self.amplitude = 0.0;
        try self.oscillator.init(waveform, 440.0, sample_rate); // Default frequency A4
    }

    /// Start the Voice with a note
    pub fn start(self: *Voice, note: u8, velocity: u8, channel: u8) void {
        self.isActive = true;
        self.note = note;
        self.velocity = velocity;
        self.channel = channel;
        self.amplitude = @as(f32, @floatFromInt(velocity)) / 127.0; // Normalize velocity (0.0 to 1.0)
        self.oscillator.set_frequency(midiNoteToFrequency(note));
        self.oscillator.reset_phase();
    }

    /// Stop the Voice
    pub fn stop(self: *Voice) void {
        self.isActive = false;
        self.amplitude = 0.0;
    }

    /// Generate a single sample for the Voice
    pub fn generate_sample(self: *Voice) f32 {
        if (!self.isActive) return 0.0;
        const osc_sample = self.oscillator.generate_sample();
        return osc_sample * self.amplitude;
    }

    /// Deinitialize the Voice
    pub fn deinit(self: *Voice) void {
        self.stop();
        // Additional cleanup if necessary
    }

    /// Convert MIDI note to frequency
    fn midiNoteToFrequency(note: u8) f32 {
        return 440.0 * math.pow(f32, 2.0, (@as(f32, @floatFromInt(note)) - 69.0) / 12.0);
    }
};

/// VoicePool Struct
pub const VoicePool = struct {
    voices: []Voice,

    /// Initialize the VoicePool with a specific number of voices and sample rate
    pub fn init(self: *VoicePool, memAllocator: std.mem.Allocator, num_voices: usize, sample_rate: f32, default_waveform: Waveform) !void {
        self.voices = try memAllocator.alloc(Voice, num_voices);
        for (self.voices) |*voice| {
            try voice.init(sample_rate, default_waveform);
        }
    }

    /// Start a note by allocating an available voice
    pub fn start_note(self: *VoicePool, note: u8, velocity: u8, channel: u8, sample_rate: f32) void {
        // Find the first inactive voice
        _ = sample_rate;
        for (self.voices) |*voice| {
            if (!voice.isActive) {
                voice.start(note, velocity, channel);
                return;
            }
        }

        // If all voices are active, implement voice stealing (e.g., steal the oldest voice)
        // For simplicity, steal the first voice
        log.info("Stealing voice for note {d}\n", .{note}, @src());
        self.voices[0].start(note, velocity, self.voices[0].channel);
    }

    /// Stop a note by deactivating the corresponding voice
    pub fn stop_note(self: *VoicePool, note: u8) void {
        for (self.voices) |*voice| {
            if (voice.isActive and voice.note == note) {
                voice.stop();
                return;
            }
        }
        log.err("Attempted to stop inactive or non-existent note {d}\n", .{note}, @src());
    }

    /// Generate the mix by summing all active voices
    pub fn generate_mix(self: *VoicePool) f32 {
        var mix: f32 = 0.0;
        for (self.voices) |voice| {
            mix += voice.generate_sample();
        }
        // Prevent clipping by limiting the mix
        if (mix > 1.0) mix = 1.0;
        if (mix < -1.0) mix = -1.0;
        return mix;
    }

    /// Free the VoicePool resources
    pub fn free(self: *VoicePool, memAllocator: *std.mem.Allocator) void {
        for (self.voices) |*voice| {
            voice.deinit();
        }
        memAllocator.free(self.voices);
    }
};

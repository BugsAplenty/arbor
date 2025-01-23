// voice_pool.zig
// Voice Pool Module for Zynth Synthesizer

const std = @import("std");
const math = std.math;
const Oscillator = @import("oscillator.zig").Oscillator;
const Waveform = @import("oscillator.zig").Waveform;

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
    pub fn init(self: *Voice, sample_rate: f32, waveform: Waveform) !void {
        // 1) we set local fields
        self.sample_rate = sample_rate;
        self.isActive = false;
        self.note = 0;
        self.velocity = 0;
        self.channel = 0;
        self.amplitude = 0.0;
        // 2) init oscillator
        try self.oscillator.init(sample_rate, waveform);
    }

    /// Start the Voice with a note
    pub fn start(self: *Voice, note: u8, velocity: u8, channel: u8) void {
        self.isActive = true;
        self.note = note;
        self.velocity = velocity;
        self.channel = channel;
        self.amplitude = @as(f32, @floatFromInt(velocity)) / 127.0; // 0..1 range
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
        // If you had to free anything, you'd do it here.
        // For now, just ensure the Voice is inactive:
        self.stop();
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
    /// matching the style: returns error union plus the struct
    pub fn init(allocator: std.mem.Allocator, num_voices: usize, sample_rate: f32) !VoicePool {
        var self = VoicePool{
            .voices = &[_]Voice{},
        };
        // allolcate
        self.voices = try allocator.alloc(Voice, num_voices);
        // init each voice
        for (self.voices) |*voice| {
            try voice.init(sample_rate, .Sine);
        }
        return self;
    }


    /// Start a note by allocating an available voice
    pub fn start_note(
        self: *VoicePool,
        note: u8,
        velocity: u8,
        channel: u8,
        sample_rate: f32,
    ) void {
        // We might not need sample_rate if each voice already has sample_rate
        _ = sample_rate;

        // Find the first inactive voice
        for (self.voices) |*voice| {
            if (!voice.isActive) {
                voice.start(note, velocity, channel);
                return;
            }
        }
        // If all voices are active, implement voice stealing
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
    }

    /// Generate the mix by summing all active voices
    pub fn generate_mix(self: *VoicePool) f32 {
        var mix: f32 = 0.0;
        for (self.voices) |voice| {
            mix += voice.generate_sample();
        }
        if (mix > 1.0) mix = 1.0;
        if (mix < -1.0) mix = -1.0;
        return mix;
    }

    pub fn deinit(self: *VoicePool, allocator: std.mem.Allocator) void {
        for (self.voices) |*voice| {
            voice.deinit();
        }
        allocator.free(self.voices);
    }
};

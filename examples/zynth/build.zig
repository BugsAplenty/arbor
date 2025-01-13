const std = @import("std");
const arbor = @import("arbor");

pub fn build(b: *std.Build) !void {
    try arbor.addPlugin(b, .{
        .description = .{
            .name = "Synth",
            .id = "com.BugsAplenty.Synth",
            .company = "BugsAplenty",
            .version = "0.1.0",
            .copyright = "MIT",
            .url = "",
            .manual = "",
            .contact = "",
            .description = "A simple synthesizer",
        },
        .features = arbor.features.STEREO | arbor.features.INSTRUMENT,
        .root_source_file = "plugin.zig",
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
}

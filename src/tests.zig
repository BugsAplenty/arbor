const std = @import("std");
const arbor = @import("arbor.zig");

test "Plugin features" {
    const span = std.mem.span;
    const features = &[_]arbor.PluginFeatures{ .stereo, .synth, .eq };

    var parsed = try arbor.parseClapFeatures(features);

    var i: u32 = 0;
    while (i < parsed.constSlice().len) : (i += 1) {
        const feat = parsed.slice()[i];
        if (feat == null) break;
        if (i == 0)
            try std.testing.expectEqualStrings(span(feat.?), "stereo");
        if (i == 1)
            try std.testing.expectEqualStrings(span(feat.?), "synthesizer");
        if (i == 2)
            try std.testing.expectEqualStrings(span(feat.?), "equalizer");
    }
}
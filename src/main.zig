const std = @import("std");

const font_path = "assets/RobotoMono.ttf";
const max_ttf_filesize = 100 * 1024 * 1024;

pub fn main() !void {
    std.debug.print("zig-otfdump\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    const font_file = try std.fs.cwd().openFile(font_path, .{ .mode = .read_only });
    defer font_file.close();

    const font_data = try font_file.readToEndAlloc(allocator, max_ttf_filesize);
    defer allocator.free(font_data);

    try dump(allocator, font_data);
}

const SectionRange = struct {
    offset: u32 = 0,
    length: u32 = 0,

    pub fn isNull(self: @This()) bool {
        return self.offset == 0;
    }
};

const DataSections = struct {
    loca: SectionRange = .{},
    head: SectionRange = .{},
    glyf: SectionRange = .{},
    hhea: SectionRange = .{},
    hmtx: SectionRange = .{},
    kern: SectionRange = .{},
    gpos: SectionRange = .{},
    svg: SectionRange = .{},
    maxp: SectionRange = .{},
    cmap: SectionRange = .{},
};

fn dump(allocator: std.mem.Allocator, font_data: []const u8) !void {
    _ = allocator;

    var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){ .buffer = font_data, .pos = 0 };
    var reader = fixed_buffer_stream.reader();

    //
    // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6.html
    //

    const scaler_type = try reader.readIntBig(u32);
    const tables_count = try reader.readIntBig(u16);
    const search_range = try reader.readIntBig(u16);
    const entry_selector = try reader.readIntBig(u16);
    const range_shift = try reader.readIntBig(u16);

    _ = scaler_type;
    _ = search_range;
    _ = entry_selector;
    _ = range_shift;

    var data_sections = DataSections{};

    var i: usize = 0;
    while (i < tables_count) : (i += 1) {
        var tag_buffer: [4]u8 = undefined;
        var tag = tag_buffer[0..];
        _ = try reader.readAll(tag[0..]);
        const checksum = try reader.readIntBig(u32);
        // TODO: Use checksum
        _ = checksum;
        const offset = try reader.readIntBig(u32);
        const length = try reader.readIntBig(u32);

        if (std.mem.eql(u8, "cmap", tag)) {
            data_sections.cmap.offset = offset;
            data_sections.cmap.length = length;
            continue;
        }

        if (std.mem.eql(u8, "loca", tag)) {
            data_sections.loca.offset = offset;
            data_sections.loca.length = length;
            continue;
        }

        if (std.mem.eql(u8, "head", tag)) {
            data_sections.head.offset = offset;
            data_sections.head.length = length;
            continue;
        }

        if (std.mem.eql(u8, "glyf", tag)) {
            data_sections.glyf.offset = offset;
            data_sections.glyf.length = length;
            continue;
        }

        if (std.mem.eql(u8, "hhea", tag)) {
            data_sections.hhea.offset = offset;
            data_sections.hhea.length = length;
            continue;
        }

        if (std.mem.eql(u8, "hmtx", tag)) {
            data_sections.hmtx.offset = offset;
            data_sections.hmtx.length = length;
            continue;
        }

        if (std.mem.eql(u8, "kern", tag)) {
            data_sections.kern.offset = offset;
            data_sections.kern.length = length;
            continue;
        }

        if (std.mem.eql(u8, "GPOS", tag)) {
            data_sections.gpos.offset = offset;
            data_sections.gpos.length = length;
            continue;
        }

        if (std.mem.eql(u8, "maxp", tag)) {
            data_sections.maxp.offset = offset;
            data_sections.maxp.length = length;
            continue;
        }
    }

    if (data_sections.head.isNull()) {
        std.log.err("Required data section `head` not found", .{});
        return error.RequiredSectionHeadMissing;
    }

    if (data_sections.hhea.isNull()) {
        std.log.err("Required data section `hhea` not found", .{});
        return error.RequiredSectionHHEAMissing;
    }

    if (data_sections.hmtx.isNull()) {
        std.log.err("Required data section `hmtx` not found", .{});
        return error.RequiredSectionHMTXMissing;
    }

    if (data_sections.maxp.isNull()) {
        std.log.err("Required data section `maxp` not found", .{});
        return error.RequiredSectionMAXPMissing;
    }

    if (data_sections.cmap.isNull()) {
        std.log.err("Required data section `cmap` not found", .{});
        return error.RequiredSectionCMAPMissing;
    }

    std.log.info("Font successfully parsed", .{});
}

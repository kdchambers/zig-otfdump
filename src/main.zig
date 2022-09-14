const std = @import("std");

const font_path = "assets/RobotoMono.ttf";
const max_ttf_filesize = 100 * 1024 * 1024;

const SectionRange = struct {
    offset: u32 = 0,
    length: u32 = 0,

    pub fn isNull(self: @This()) bool {
        return self.offset == 0;
    }
};

const DataSections = struct {
    dsig: SectionRange = .{},
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
    name: SectionRange = .{},
};

const PlatformID = enum(u16) {
    unicode = 0,
    macintosh = 1,
    reserved = 2,
    microsoft = 3,
    _,
};

const CMAPPlatformSpecificID = packed union {
    const Unicode = enum(u16) {
        version1_0 = 0,
        version1_1 = 1,
        iso_10646 = 2,
        unicode2_0_bmp_only = 3,
        unicode2_0 = 4,
        unicode_variation_sequences = 5,
        last_resort = 6,
        _,
    };

    // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6name.html
    const Macintosh = enum(u16) {
        roman = 0,
        japanese = 1,
        traditional_chinese = 2,
        korean = 3,
        arabic = 4,
        hebrew = 5,
        greek = 6,
        russion = 7,
        rsymbol = 8,
        devanagari = 9,
        gurmukhi = 10,
        gujarati = 11,
        oriya = 12,
        bengali = 13,
        tamil = 14,
        teluga = 15,
        kannada = 16,
        malayalam = 17,
        sinhalese = 18,
        burmese = 19,
        khmer = 20,
        thai = 21,
        laotian = 22,
        georgian = 23,
        armenian = 24,
        simplified_chinese = 25,
        tibetan = 26,
        mongolian = 27,
        geez = 28,
        slavic = 29,
        vietnamese = 30,
        sindhi = 31,
        uninterpreted = 32,
        _,
    };

    const Microsoft = enum(u16) {
        symbol = 0,
        unicode_bmp_only = 1,
        shift_jis = 2,
        prc = 3,
        big_five = 4,
        johab = 5,
        unicode_ucs_4 = 10,
    };

    unicode: Unicode,
    microsoft: Microsoft,
    macintosh: Macintosh,
};

fn BoundingBox(comptime T: type) type {
    return struct {
        x_min: T,
        y_min: T,
        x_max: T,
        y_max: T,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    const font_file = try std.fs.cwd().openFile(font_path, .{ .mode = .read_only });
    defer font_file.close();

    const font_data = try font_file.readToEndAlloc(allocator, max_ttf_filesize);
    defer allocator.free(font_data);

    try dump(allocator, font_data);
}

fn dump(allocator: std.mem.Allocator, font_data: []const u8) !void {
    const print = std.debug.print;

    var data_sections = DataSections{};

    {
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

        print("======== Tables found ========\n", .{});

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

            print("{d:2}.    {s}\n", .{ i + 1, tag });

            if (std.mem.eql(u8, "cmap", tag)) {
                data_sections.cmap.offset = offset;
                data_sections.cmap.length = length;
                continue;
            }

            if (std.mem.eql(u8, "DSIG", tag)) {
                data_sections.dsig.offset = offset;
                data_sections.dsig.length = length;
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

            if (std.mem.eql(u8, "name", tag)) {
                data_sections.name.offset = offset;
                data_sections.name.length = length;
                continue;
            }
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

    print("\n======== Dumping tables ========\n", .{});

    {
        print("\nDSIG\n", .{});
        var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){
            .buffer = font_data,
            .pos = data_sections.dsig.offset,
        };
        var reader = fixed_buffer_stream.reader();

        const version = try reader.readIntBig(u32);
        const signature_count = try reader.readIntBig(u16);
        const flags = try reader.readIntBig(u16);

        print("  version: {d}\n", .{version});
        print("  flags: {d}\n", .{flags});

        if(signature_count == 0) {
            print("\n  No signature records found\n", .{});
        }

        const SignatureRecord = extern struct {
            format: u32,
            length: u32,
            signature_offset_block: u32,
        };

        var signature_records = try allocator.alloc(SignatureRecord, signature_count);
        defer allocator.free(signature_records);

        var i: usize = 0;
        while(i < signature_count) : (i += 1) {
            signature_records[i] = try reader.readStruct(SignatureRecord);
            print("    {d} format {d} length {d}\n", .{i + 1, signature_records[i].format, signature_records[i].length});
        }
    }

    {
        //
        // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6maxp.html
        //

        print("\nmaxp (required)\n", .{});
        var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){
            .buffer = font_data,
            .pos = data_sections.maxp.offset,
        };
        var reader = fixed_buffer_stream.reader();

        const version_major = try reader.readIntBig(i16);
        const version_minor = try reader.readIntBig(i16);
        const glyph_count = try reader.readIntBig(u16);
        const max_points = try reader.readIntBig(u16);
        const max_contours = try reader.readIntBig(u16);
        const max_component_points = try reader.readIntBig(u16);
        const max_component_contours = try reader.readIntBig(u16);
        const max_zones = try reader.readIntBig(u16);
        const max_twilight_points = try reader.readIntBig(u16);
        const max_storage = try reader.readIntBig(u16);
        const max_function_defs = try reader.readIntBig(u16);
        const max_instruction_defs = try reader.readIntBig(u16);
        const max_stack_elements = try reader.readIntBig(u16);
        const max_sizeof_instructions = try reader.readIntBig(u16);
        const max_component_elements = try reader.readIntBig(u16);
        const max_component_depth = try reader.readIntBig(u16);

        print("  version:                 {d}.{d}\n", .{ version_major, version_minor });
        print("  glyph_count:             {d}\n", .{glyph_count});
        print("  max_points:              {d}\n", .{max_points});
        print("  max_contours:            {d}\n", .{max_contours});
        print("  max_component_points:    {d}\n", .{max_component_points});
        print("  max_component_contours:  {d}\n", .{max_component_contours});
        print("  max_zones:               {d}\n", .{max_zones});
        print("  max_twilight_points:     {d}\n", .{max_twilight_points});
        print("  max_storage:             {d}\n", .{max_storage});
        print("  max_function_defs:       {d}\n", .{max_function_defs});
        print("  max_instruction_defs:    {d}\n", .{max_instruction_defs});
        print("  max_stack_elements:      {d}\n", .{max_stack_elements});
        print("  max_sizeof_instructions: {d}\n", .{max_sizeof_instructions});
        print("  max_component_elements:  {d}\n", .{max_component_elements});
        print("  max_component_depth:     {d}\n", .{max_component_depth});
    }

    {
        //
        // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6head.html
        //

        print("\nhead (required)\n", .{});

        var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){
            .buffer = font_data,
            .pos = data_sections.head.offset,
        };
        var reader = fixed_buffer_stream.reader();

        const version_major = try reader.readIntBig(i16);
        const version_minor = try reader.readIntBig(i16);
        const font_revision_major = try reader.readIntBig(u16);
        const font_revision_minor = try reader.readIntBig(u16);
        const checksum_adjustment = try reader.readIntBig(u32);
        const magic_number = try reader.readIntBig(u32);

        if (magic_number != 0x5F0F3CF5) {
            std.log.warn("Magic number not set to 0x5F0F3CF5. File might be corrupt", .{});
        }

        const Flags = packed struct(u16) {
            y0_specifies_baseline: bool,
            left_blackbit_is_lsb: bool,
            scaled_point_size_differs: bool,
            use_integer_scaling: bool,
            reserved_microsoft: bool,
            layout_vertically: bool,
            reserved_0: bool,
            requires_layout_for_ling_rendering: bool,
            aat_font_with_metamorphosis_effects: bool,
            strong_right_to_left: bool,
            indic_style_effects: bool,
            reserved_adobe_0: bool,
            reserved_adobe_1: bool,
            reserved_adobe_2: bool,
            reserved_adobe_3: bool,
            simple_generic_symbols: bool,
        };

        const flags = try reader.readStruct(Flags);

        const units_per_em = try reader.readIntBig(u16);
        const created_timestamp = try reader.readIntBig(i64);
        const modified_timestamp = try reader.readIntBig(i64);

        var bounding_box: BoundingBox(i16) = undefined;
        bounding_box.x_min = try reader.readIntBig(i16);
        bounding_box.y_min = try reader.readIntBig(i16);
        bounding_box.x_max = try reader.readIntBig(i16);
        bounding_box.y_max = try reader.readIntBig(i16);

        const MacStyle = packed struct(u16) {
            bold: bool,
            italic: bool,
            underline: bool,
            outline: bool,
            shadow: bool,
            extended: bool,
            unused_bit_6: bool,
            unused_bit_7: bool,
            unused_bit_8: bool,
            unused_bit_9: bool,
            unused_bit_10: bool,
            unused_bit_11: bool,
            unused_bit_12: bool,
            unused_bit_13: bool,
            unused_bit_14: bool,
            unused_bit_15: bool,
        };

        const mac_style = try reader.readStruct(MacStyle);

        const lowest_rec_ppem = try reader.readIntBig(u16);

        // TODO: This crashes the compiler. Update when fixed
        // const FontDirectionHint = enum(i16) {
        //     only_right_to_left_neutrals = -2,
        //     only_right_to_left = -1,
        //     mixed = 0,
        //     only_left_to_right = 1,
        //     only_left_to_right_neutrals = 1,
        //     invalid = std.math.maxInt(i16),
        // };
        // const font_direction_hint = reader.readEnum(FontDirectionHint, .Big) catch blk: {
        //     std.log.warn("Invalid `FontDirectionHint` value in `head` table", .{});
        //     break :blk FontDirectionHint.invalid;
        // };

        const font_direction_hint = try reader.readIntBig(i16);
        const index_to_loc_format = try reader.readIntBig(i16);
        const glyph_data_format = try reader.readIntBig(i16);

        print("  version:             {d}.{d}\n", .{ version_major, version_minor });
        print("  font revision:       {d}.{d}\n", .{ font_revision_major, font_revision_minor });
        print("  checksum_adjustment: {d}\n", .{checksum_adjustment});
        print("  magic_number:        {x}\n", .{magic_number});
        print("  flags:               {x}\n", .{@bitCast(u16, flags)});
        print("  units_per_em:        {d}\n", .{units_per_em});
        print("  created_timestamp:   {d}\n", .{created_timestamp});
        print("  modified_timestamp:  {d}\n", .{modified_timestamp});
        print("  bounding_box:        ({d}, {d}) -> ({d}, {d})\n", .{
            bounding_box.x_min,
            bounding_box.y_min,
            bounding_box.x_max,
            bounding_box.y_max,
        });
        print("  mac_style:           {x}\n", .{@bitCast(u16, mac_style)});
        print("  lowest_rec_ppem:     {d}\n", .{lowest_rec_ppem});
        print("  font_direction_hint: {d}\n", .{font_direction_hint});
        print("  index_to_loc_format: {d}\n", .{index_to_loc_format});
        print("  glyph_data_format:   {d}\n", .{glyph_data_format});
    }

    var long_hor_metrics_count: u16 = undefined;
    {
        print("\nhhea (required)\n", .{});
        var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){
            .buffer = font_data,
            .pos = data_sections.hhea.offset,
        };
        var reader = fixed_buffer_stream.reader();

        const version_major = try reader.readIntBig(i16);
        const version_minor = try reader.readIntBig(i16);
        const ascent = try reader.readIntBig(i16);
        const descent = try reader.readIntBig(i16);
        const line_gap = try reader.readIntBig(i16);
        const advance_width_max = try reader.readIntBig(u16);
        const min_leftside_bearing = try reader.readIntBig(i16);
        const min_rightside_bearing = try reader.readIntBig(i16);
        const x_max_extent = try reader.readIntBig(i16);
        const caret_slope_rise = try reader.readIntBig(i16);
        const caret_slope_run = try reader.readIntBig(i16);
        const caret_offset = try reader.readIntBig(i16);
        try reader.skipBytes(@sizeOf(u16) * 4, .{});
        const metric_data_format = try reader.readIntBig(i16);
        long_hor_metrics_count = try reader.readIntBig(u16);

        print("  version:                {d}.{d}\n", .{ version_major, version_minor });
        print("  ascent:                 {d}\n", .{ascent});
        print("  descent:                {d}\n", .{descent});
        print("  line_gap:               {d}\n", .{line_gap});
        print("  advance_width_max:      {d}\n", .{advance_width_max});
        print("  min_leftside_bearing:   {d}\n", .{min_leftside_bearing});
        print("  min_rightside_bearing:  {d}\n", .{min_rightside_bearing});
        print("  x_max_extent:           {d}\n", .{x_max_extent});
        print("  caret_slope_rise:       {d}\n", .{caret_slope_rise});
        print("  caret_slope_run:        {d}\n", .{caret_slope_run});
        print("  caret_offset:           {d}\n", .{caret_offset});
        print("  metric_data_format:     {d}\n", .{metric_data_format});
        print("  long_hor_metrics_count: {d}\n", .{long_hor_metrics_count});
    }

    {
        print("\nhmtx (required)\n", .{});
        var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){
            .buffer = font_data,
            .pos = data_sections.hmtx.offset,
        };
        var reader = fixed_buffer_stream.reader();

        const HorizontalMetric = extern struct {
            advance_width: u16,
            leftside_bearing: i16,
        };

        comptime {
            std.debug.assert(@sizeOf(HorizontalMetric) == 4);
        }

        var horizontal_metrics = try allocator.alloc(HorizontalMetric, long_hor_metrics_count);
        defer allocator.free(horizontal_metrics);

        print("  Horizontal metrics:\n", .{});

        var i: usize = 0;
        while (i < long_hor_metrics_count) : (i += 1) {
            horizontal_metrics[i] = try reader.readStruct(HorizontalMetric);
            print("    {d:2}. advance width {d}. leftside bearing {d}\n", .{
                i + 1,
                horizontal_metrics[i].advance_width,
                horizontal_metrics[i].leftside_bearing,
            });
        }

        // TODO: Load + render leftSideBearing array
    }

    {
        print("\ncmap (required)\n", .{});
        var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){
            .buffer = font_data,
            .pos = data_sections.cmap.offset,
        };
        var reader = fixed_buffer_stream.reader();

        const version = try reader.readIntBig(u16);
        const subtable_count = try reader.readIntBig(u16);

        print("  version: {d}\n", .{version});
        print("  subtables:\n", .{});
        var i: usize = 0;
        while (i < subtable_count) : (i += 1) {
            const platform_id = try reader.readEnum(PlatformID, .Big);
            const platform_spec_string = blk: {
                const raw_value = try reader.readIntBig(u16);
                switch (platform_id) {
                    .unicode => break :blk @tagName(@intToEnum(CMAPPlatformSpecificID.Unicode, raw_value)),
                    .macintosh => break :blk @tagName(@intToEnum(CMAPPlatformSpecificID.Macintosh, raw_value)),
                    .reserved => {
                        std.log.err("Reserved CMAP platform ID used within file\n", .{});
                        return error.CMAPInvalid;
                    },
                    .microsoft => break :blk @tagName(@intToEnum(CMAPPlatformSpecificID.Microsoft, raw_value)),
                    else => {
                        std.log.err("Invalid CMAP platform ID parsed\n", .{});
                        return error.CMAPInvalid;
                    },
                }
            };
            const offset = try reader.readIntBig(u32);
            _ = offset;
            print("    {d:2}. {s}.{s}\n", .{ i + 1, @tagName(platform_id), platform_spec_string });
        }
    }

    if (!data_sections.name.isNull()) {
        print("\nname\n", .{});
        var fixed_buffer_stream = std.io.FixedBufferStream([]const u8){
            .buffer = font_data,
            .pos = data_sections.name.offset,
        };
        var reader = fixed_buffer_stream.reader();

        const format = try reader.readIntBig(u16);
        const count = try reader.readIntBig(u16);
        const string_offset = try reader.readIntBig(u16);

        if (format != 0) {
            std.log.err("Format {d} for name table not implemented", .{format});
            return;
        }

        const PlatformSpecificID = u16;
        const LanguageID = u16;

        const NameIdentifierCode = enum(u16) {
            copyright = 0,
            font_family = 1,
            font_subfamily = 2,
            unique_subfamily_id = 3,
            font_fullname = 4,
            table_version = 5,
            postscript_name = 6,
            trademark_notice = 7,
            manufacturer_name = 8,
            designer = 9,
            typeface_description = 10,
            font_vendor_url = 11,
            font_designer_url = 12,
            license_description = 13,
            license_information_url = 14,
            reserved_0 = 15,
            preferred_family = 16,
            preferred_subfamily = 17,
            compatible_full = 18,
            sample_text = 19,
            wws_family_name = 21,
            wws_subfamily_name = 22,
            light_background_palette = 23,
            dark_background_palette = 24,
            unknown = std.math.maxInt(u16),
            _,
        };

        const NameRecord = extern struct {
            platform_id: PlatformID,
            platform_specific_id: PlatformSpecificID,
            language_id: LanguageID,
            name_id: NameIdentifierCode,
            length: u16,
            offset: u16,
        };

        comptime {
            std.debug.assert(@sizeOf(NameRecord) == 12);
        }

        var name_records = try allocator.alloc(NameRecord, count);
        defer allocator.free(name_records);

        for (name_records) |*name_record| {
            name_record.*.platform_id = try reader.readEnum(PlatformID, .Big);
            name_record.*.platform_specific_id = try reader.readIntBig(PlatformSpecificID);
            name_record.*.language_id = try reader.readIntBig(LanguageID);
            name_record.*.name_id = reader.readEnum(NameIdentifierCode, .Big) catch .unknown;
            name_record.*.length = try reader.readIntBig(u16);
            name_record.*.offset = try reader.readIntBig(u16);
        }

        print("  Found records:\n", .{});
        const data_section_offset = @intCast(usize, data_sections.name.offset);
        const base_string_buffer = font_data[data_section_offset + string_offset ..];
        for (name_records) |*name_record, name_record_i| {
            const name_record_offset = @intCast(usize, name_record.offset);
            const string_value = base_string_buffer[name_record_offset .. name_record_offset + name_record.length];
            switch (name_record.name_id) {
                .copyright => print("    {d:2}. copyright:               \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .font_family => print("    {d:2}. font family:             \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .font_subfamily => print("    {d:2}. font subfamily:          \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .unique_subfamily_id => print("    {d:2}. unique font subfamily:   \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .font_fullname => print("    {d:2}. font fullname:           \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .table_version => print("    {d:2}. table version:           \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .postscript_name => print("    {d:2}. postscript name:         \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .trademark_notice => print("    {d:2}. trademark notice:        \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .manufacturer_name => print("    {d:2}. manufactorer name:       \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .designer => print("    {d:2}. designer:                \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .typeface_description => print("    {d:2}. typeface description: \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .font_vendor_url => print("    {d:2}. font vendor url:         \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .font_designer_url => print("    {d:2}. font designer url:       \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .license_description => print("    {d:2}. license description:     \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .license_information_url => print("    {d:2}. license description url: \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .preferred_family => print("    {d:2}. preferred family:        \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .preferred_subfamily => print("    {d:2}. preferred subfamily:     \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .compatible_full => print("    {d:2}. compatible full:         \"{s}\"\n", .{ name_record_i + 1, string_value }),
                .sample_text => print("    {d:2}. sample text:             \"{s}\"\n", .{ name_record_i + 1, string_value }),
                else => print("    {d:2}. unknown:                 \"{s}\"\n", .{ name_record_i + 1, string_value }),
            }
        }
    }

    print("\nFont successfully parsed\n", .{});
}

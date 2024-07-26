const std = @import("std");
const testing = std.testing;

const PrintHeader = enum {
    always,
    once,
    never,
};

const PrintTarget = enum {
    csv,
    stdout,
    both,
};

const Config = struct {
    print_header: PrintHeader,
    print_target: PrintTarget,
    filename: []const u8,
};

pub fn CSVWriter(Row: anytype) type {
    return CSVWriterWithPrecision(Row, 2);
}

pub fn CSVWriterWithPrecision(Row: anytype, float_precision: comptime_int) type {
    return struct {
        const Self = @This();
        config: Config,
        printed_header: bool = false,

        pub fn init(config: Config) Self {
            return Self{
                .config = config,
                .printed_header = false,
            };
        }

        pub fn add_row(self: *Self, row: Row) !void {
            const print_header_csv = !try self.file_exists();

            const print_header = switch (self.config.print_header) {
                .never => false,
                .always => true,
                .once => !self.printed_header,
            };

            self.printed_header = true;

            switch (self.config.print_target) {
                .csv => {
                    try self.row_to_csv(row, print_header_csv);
                },
                .stdout => {
                    try row_to_stdout(row, print_header);
                },
                .both => {
                    try self.row_to_csv(row, print_header_csv);
                    try row_to_stdout(row, print_header);
                },
            }
        }

        fn file_exists(self: *const Self) !bool {
            std.fs.cwd().access(self.config.filename, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => return false,
                else => return err,
            };
            return true;
        }

        fn row_to_stdout(row: Row, print_header: bool) !void {
            const writer = std.io.getStdOut().writer();
            try serialize_row(writer, row, print_header);
        }

        fn row_to_csv(self: *const Self, row: Row, print_header: bool) !void {
            const file = try open_or_create_file(self.config.filename);
            defer file.close();

            // Append to the file
            const stat = try file.stat();
            try file.seekTo(stat.size);

            const writer = file.writer();
            try serialize_row(writer, row, print_header);
        }

        fn open_or_create_file(filename: []const u8) !std.fs.File {
            return std.fs.cwd().openFile(filename, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => std.fs.cwd().createFile(filename, .{ .read = true }),
                else => return err,
            };
        }

        fn serialize_row(writer: anytype, row: Row, print_header: bool) !void {
            if (print_header) {
                inline for (std.meta.fields(@TypeOf(row)), 0..) |f, i| {
                    if (i > 0) try writer.print(",", .{});
                    try writer.print("{s}", .{f.name});
                }
                try writer.print("\n", .{});
            }
            inline for (std.meta.fields(@TypeOf(row)), 0..) |f, i| {
                if (i > 0) try writer.print(",", .{});
                switch (@typeInfo(f.type)) {
                    .Int => {
                        try writer.print("{d}", .{@field(row, f.name)});
                    },
                    .Float => {
                        const format_str = std.fmt.comptimePrint("{{d:.{d}}}", .{float_precision});
                        try writer.print(format_str, .{@field(row, f.name)});
                    },
                    .Pointer => {
                        try writer.print("{s}", .{@field(row, f.name)});
                    },
                    else => {
                        @panic("Type not supported for serialization");
                    },
                }
            }
            try writer.print("\n", .{});
        }
    };
}

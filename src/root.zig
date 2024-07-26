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

pub fn CSVWriterType(
    Row: anytype,
) type {
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
            const print_header_csv = if (self.file_exists()) false else true;

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
                    self.row_to_stdout(row, print_header);
                },
                .both => {
                    try self.row_to_csv(row, print_header_csv);
                    self.row_to_stdout(row, print_header);
                },
            }
        }

        fn file_exists(self: *const Self) bool {
            std.fs.Dir.access(std.fs.cwd(), self.config.filename, .{ .mode = .read_write }) catch {
                return false;
            };
            return true;
        }

        fn row_to_stdout(self: *const Self, row: Row, print_header: bool) void {
            _ = self;
            const writer = std.io.getStdOut().writer();
            serialize_row(
                writer,
                row,
                print_header,
            ) catch unreachable;
        }

        fn row_to_csv(self: *const Self, row: Row, print_header: bool) !void {

            // Open or create file
            const file = std.fs.cwd().openFile(self.config.filename, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => try std.fs.cwd().createFile(self.config.filename, .{ .read = true }),
                else => |e| return e,
            };
            defer file.close();

            // Append
            const stat = try file.stat();
            try file.seekTo(stat.size);

            const writer = file.writer();
            try serialize_row(writer, row, print_header);
        }

        fn serialize_row(writer: anytype, row: Row, print_header: bool) !void {
            if (print_header) {
                inline for (std.meta.fields(@TypeOf(row)), 0..) |f, i| {
                    if (i > 0) try writer.print(",", .{});
                    try writer.print("{s}", .{f.name});
                }
                try writer.print("\n", .{});
            }
            {
                inline for (std.meta.fields(@TypeOf(row)), 0..) |f, i| {
                    if (i > 0) try writer.print(",", .{});
                    switch (@typeInfo(f.type)) {
                        .Int => {
                            try writer.print("{d}", .{@field(row, f.name)});
                        },
                        .Float => {
                            try writer.print("{d:.4}", .{@field(row, f.name)});
                        },
                        .Pointer => {
                            try writer.print("{s}", .{@field(row, f.name)});
                        },
                        else => {
                            @panic("Yype not supported to serialize");
                        },
                    }
                }
                try writer.print("\n", .{});
            }
        }
    };
}

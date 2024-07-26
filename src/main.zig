const std = @import("std");
const assert = std.debug.assert;
const csv_writer = @import("csv-writer");

const Config = struct {
    name: *const [4:0]u8 = "test",
    ip: []const u8 = "127.0.0.1",
    samples: usize,
    count: usize,
    cpus: f64,
};

pub fn main() !void {
    const config = Config{
        .samples = 10,
        .count = 1,
        .cpus = 0.1,
    };

    var csvwriter = csv_writer.CSVWriter(Config).init(.{
        .print_header = .once,
        .print_target = .both,
        .filename = "result.csv",
    });

    try csvwriter.add_row(config);

    //enum PrintHeader{
    //.always
    //.first
    //.never
    //};

    //std.debug.print("", .{});
    //try print_csv("result.csv", config, true);
}

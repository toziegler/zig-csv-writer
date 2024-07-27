const std = @import("std");
const assert = std.debug.assert;
const csv_writer = @import("csv-writer");

const Row = struct {
    name: *const [4:0]u8 = "test",
    ip: []const u8 = "127.0.0.1",
    samples: usize,
    count: usize,
    cpus: f64,
    use_config: bool,
};

pub fn main() !void {
    const row = Row{
        .samples = 10,
        .count = 1,
        .cpus = 0.1,
        .use_config = true,
    };

    var csvwriter = csv_writer.CSVWriter(Row).init(.{
        .print_header = .once,
        .print_target = .both,
        .filename = "result.csv",
    });

    try csvwriter.add_row(row);
}

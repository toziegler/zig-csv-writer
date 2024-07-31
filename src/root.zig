const std = @import("std");

/// Enum representing the options for printing the header.
const PrintHeader = enum {
    /// Always print the header.
    always,
    /// Print the header once.
    once,
    /// Never print the header.
    never,
};

/// Enum representing the target for printing.
const PrintTarget = enum {
    /// Print to CSV file.
    csv,
    /// Print to standard output.
    stdout,
    /// Print to both CSV file and standard output.
    both,
};

/// Configuration structure for CSVWriter.
const Config = struct {
    /// Option for printing the header.
    print_header: PrintHeader,
    /// Target for printing.
    print_target: PrintTarget,
    /// Filename for the CSV file.
    filename: []const u8,
};

/// Creates a CSVWriter with default float precision.
///
/// # Example
/// ```zig
/// const std = @import("std");
/// const csv_writer = @import("csv-writer");
///
/// const Row = struct {
///     name: *const [4:0]u8 = "test",
///     ip: []const u8 = "127.0.0.1",
///     samples: usize,
///     count: usize,
///     cpus: f64,
/// };
///
/// pub fn main() !void {
///     const row = Row{
///         .samples = 10,
///         .count = 1,
///         .cpus = 0.1,
///     };
///
///     var csvwriter = csv_writer.CSVWriter(Row).init(.{
///         .print_header = .once,
///         .print_target = .both,
///         .filename = "result.csv",
///     });
///
///     try csvwriter.add_row(row);
/// }
/// ```
pub fn CSVWriter(
    /// Type-Struct which defines the columns of the rows
    Row: anytype,
) type {
    return CSVWriterWithPrecision(Row, 2);
}

/// Creates a CSVWriter with specified float precision.
///
/// # Example
/// ```zig
/// const std = @import("std");
/// const csv_writer = @import("csv-writer");
///
/// const Row = struct {
///     name: *const [4:0]u8 = "test",
///     ip: []const u8 = "127.0.0.1",
///     samples: usize,
///     count: usize,
///     cpus: f64,
/// };
///
/// pub fn main() !void {
///     const row = Row{
///         .samples = 10,
///         .count = 1,
///         .cpus = 0.1,
///     };
///
///     var csvwriter = csv_writer.CSVWriterWithPrecision(Row, 3).init(.{
///         .print_header = .once,
///         .print_target = .both,
///         .filename = "result.csv",
///     });
///
///     try csvwriter.add_row(row);
/// }
/// ```
pub fn CSVWriterWithPrecision(
    /// Type-Struct which defines the columns of the rows
    Row: anytype,
    /// Number of decimal positions to print for floats
    float_precision: comptime_int,
) type {
    return struct {
        const Self = @This();
        config: Config,
        printed_header: bool = false,

        /// Initializes the CSVWriter with the given configuration.
        ///
        /// # Returns
        /// - `Self`: An instance of the CSVWriter.
        ///
        /// # Example
        /// ```zig
        /// const std = @import("std");
        /// const csv_writer = @import("csv-writer");
        ///
        /// const Row = struct {
        ///     name: *const [4:0]u8 = "test",
        ///     ip: []const u8 = "127.0.0.1",
        ///     samples: usize,
        ///     count: usize,
        ///     cpus: f64,
        /// };
        ///
        /// pub fn main() !void {
        ///     var csvwriter = csv_writer.CSVWriter(Config).init(.{
        ///         .print_header = .once,
        ///         .print_target = .both,
        ///         .filename = "result.csv",
        ///     });
        /// }
        /// ```
        pub fn init(
            ///  The configuration for the CSVWriter.
            config: Config,
        ) Self {
            return Self{
                .config = config,
                .printed_header = false,
            };
        }

        /// Adds a row to the CSV file or stdout based on the configuration.
        ///
        /// # Example
        /// ```zig
        /// const std = @import("std");
        /// const csv_writer = @import("csv-writer");
        ///
        /// const Row = struct {
        ///     name: *const [4:0]u8 = "test",
        ///     ip: []const u8 = "127.0.0.1",
        ///     samples: usize,
        ///     count: usize,
        ///     cpus: f64,
        /// };
        ///
        /// pub fn main() !void {
        ///     const row = Row{
        ///         .samples = 10,
        ///         .count = 1,
        ///         .cpus = 0.1,
        ///     };
        ///
        ///     var csvwriter = csv_writer.CSVWriter(Row).init(.{
        ///         .print_header = .once,
        ///         .print_target = .both,
        ///         .filename = "result.csv",
        ///     });
        ///
        ///     try csvwriter.add_row(row);
        /// }
        /// ```
        pub fn add_row(
            self: *Self,
            /// The row to be added.
            row: Row,
        ) !void {
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

        /// Checks if the CSV file exists.
        ///
        /// # Returns
        /// - `bool`: `true` if the file exists, `false` otherwise.
        fn file_exists(self: *const Self) !bool {
            std.fs.cwd().access(self.config.filename, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => return false,
                else => return err,
            };
            return true;
        }

        /// Writes a row to standard output.
        ///
        /// # Parameters
        /// - `row`: The row to be written.
        /// - `print_header`: Boolean indicating whether to print the header.
        fn row_to_stdout(row: Row, print_header: bool) !void {
            const writer = std.io.getStdOut().writer();
            try serialize_row(writer, row, print_header);
        }

        /// Writes a row to the CSV file.
        ///
        /// # Parameters
        /// - `row`: The row to be written.
        /// - `print_header`: Boolean indicating whether to print the header.
        fn row_to_csv(self: *const Self, row: Row, print_header: bool) !void {
            const file = try open_or_create_file(self.config.filename);
            defer file.close();

            // Append to the file
            const stat = try file.stat();
            try file.seekTo(stat.size);

            const writer = file.writer();
            try serialize_row(writer, row, print_header);
        }

        /// Opens or creates the CSV file.
        ///
        /// # Parameters
        /// - `filename`: The name of the file to be opened or created.
        ///
        /// # Returns
        /// - `std.fs.File`: The file handle.
        fn open_or_create_file(filename: []const u8) !std.fs.File {
            return std.fs.cwd().openFile(filename, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => std.fs.cwd().createFile(filename, .{ .read = true, .truncate = true }),
                else => return err,
            };
        }

        /// Serializes a row to the given writer.
        ///
        /// # Parameters
        /// - `writer`: The writer to which the row is serialized.
        /// - `row`: The row to be serialized.
        /// - `print_header`: Boolean indicating whether to print the header.
        ///
        /// # Returns
        /// - `void`: On successful serialization.
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
                    .Bool => {
                        try writer.print("{}", .{@field(row, f.name)});
                    },
                    .Enum => {
                        try writer.print("{any}", .{@field(row, f.name)});
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

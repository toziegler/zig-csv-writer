# Install 

```bash
zig fetch --save https://github.com/toziegler/zig-csv-writer/archive/master.tar.gz
```

```zig
    const csvwriter = b.dependency("csv-writer", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport(name: "csv-writer", module: csvwriter.module("csv-writer"));
```

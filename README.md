# Install 

```bash
zig fetch --save https://github.com/toziegler/zig-csv-writer/archive/master.tar.gz
```

```zig
    const csvwriter = b.dependency("csvwriter", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport(name: "csvwriter", module: csvwriter.module("csv-writer"));
```

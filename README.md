# toml-vala

A pure-Vala implementation of a TOML v1.0.0 parser, designed to be lightweight, fast, and easy to integrate into Vala projects. This library avoids external C dependencies, making it platform-independent and suitable for cross-compilation.

## Features

- **Full TOML v1.0.0 Support**: Parses all TOML constructs including tables, arrays, inline tables, array-of-tables, strings (basic and literal, single-line and multi-line), numbers (integers and floats), booleans, and datetimes.
- **Tree-Based Data Model**: Uses a `TomlValue` tree structure for easy navigation and access.
- **Serialization**: Supports serialization back to TOML format and to JSON.
- **Asynchronous Parsing**: Includes async file parsing APIs using GLib/GIO.
- **File Watching**: Provides a `TomlWatcher` class for hot-reloading on file changes.
- **Error Handling**: Comprehensive error reporting with `TomlError` domain.
- **UTF-8 Support**: Handles Unicode in strings, keys, and comments.
- **Dependencies**: Only requires GLib, Gee, and json-glib (for JSON serialization).

## Installation

### Building from Source

1. Ensure you have Vala and GLib development packages installed.
2. Clone the repository:
   ```
   git clone https://github.com/dardevelin/toml-vala.git
   cd toml-vala
   ```
3. Build the library:
   ```
   make
   ```
   This will compile the Vala source into a shared library (`libtoml-vala.so`) and generate a VAPI file for integration.

### Integration into Your Project

To use toml-vala in your Vala project:

1. Add the VAPI file to your Vala compiler flags:
   ```
   valac --vapidir=path/to/toml-vala --pkg toml-vala your_source.vala
   ```
2. Link against the shared library:
   ```
   gcc -o your_program your_source.o -Lpath/to/toml-vala -ltoml-vala -lgee-0.8 -ljson-glib-1.0 -lgio-2.0 -lglib-2.0
   ```

For meson builds, add the library as a subproject or dependency.

## Usage

### Basic Parsing

```vala
using Gee;

public static int main(string[] args) {
    try {
        var root = TomlParser.parse_file("config.toml");
        
        // Access values
        var title = root.get("title").string_val;
        var port = root.get("server").get("port").int_val;
        
        // Iterate over arrays
        var servers = root.get("servers").array_val;
        foreach (var server in servers) {
            var name = server.get("name").string_val;
            print("Server: %s\n", name);
        }
    } catch (TomlError e) {
        stderr.printf("Error: %s\n", e.message);
        return 1;
    }
    return 0;
}
```

### Asynchronous Parsing

```vala
using Gee;
using GLib;

public static async void parse_async() {
    try {
        var root = yield TomlParser.parse_file_async("config.toml");
        // Use root as above
    } catch (TomlError e) {
        stderr.printf("Error: %s\n", e.message);
    }
}
```

### File Watching

```vala
using Gee;
using GLib;

public static int main() {
    var watcher = new TomlWatcher("config.toml");
    watcher.changed.connect((root) => {
        print("Config reloaded!\n");
        // Handle config changes
    });
    watcher.start();
    
    var loop = new MainLoop();
    loop.run();
    return 0;
}
```

### Serialization

```vala
using Gee;

public static int main() {
    try {
        var root = TomlParser.parse_file("config.toml");
        
        // Serialize to TOML
        var toml_str = root.to_toml();
        print("%s\n", toml_str);
        
        // Serialize to JSON
        var json_str = root.to_json();
        print("%s\n", json_str);
    } catch (TomlError e) {
        stderr.printf("Error: %s\n", e.message);
        return 1;
    }
    return 0;
}
```

## API Reference

### TomlValue

- `TomlType val_type`: The type of the value.
- `string? string_val`: String value (for STRING, DATETIME).
- `int64 int_val`: Integer value.
- `double float_val`: Float value.
- `bool bool_val`: Boolean value.
- `Gee.ArrayList<TomlValue>? array_val`: Array value.
- `Gee.HashMap<string, TomlValue>? table_val`: Table value.

Methods:
- `TomlValue? get(string key)`: Get a value from a table.
- `TomlValue? get_index(int index)`: Get a value from an array.
- `string to_toml()`: Serialize to TOML string.
- `string to_json()`: Serialize to JSON string.

### TomlParser

Static methods:
- `TomlValue parse_file(string filename) throws TomlError`: Parse a TOML file synchronously.
- `async TomlValue parse_file_async(string filename) throws TomlError`: Parse a TOML file asynchronously.

### TomlWatcher

- `TomlWatcher(string filename)`: Constructor.
- `void start()`: Start watching the file.
- `void stop()`: Stop watching.
- `signal void changed(TomlValue root)`: Emitted when the file changes and is re-parsed.

### TomlError

Error domain with codes: INVALID_SYNTAX, INVALID_VALUE, DUPLICATE_KEY, MISSING_KEY.

## Limitations

- Datetimes are stored as strings; full RFC3339 parsing may be added in future versions.
- Unicode escape sequences (\u/\U) are not fully decoded; basic handling is implemented.
- The `to_toml()` serializer is simple and may not preserve all formatting/comments.
- No support for binary data or extensions beyond TOML v1.0.0.

## Contributing

Contributions are welcome! Please submit issues and pull requests on GitHub.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
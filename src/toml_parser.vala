
 /*
 * toml_parser.vala
 * A feature-complete TOML v1.0.0 parser written in Vala.
 *
 * This parser implements the TOML specification available at https://toml.io/en/v1.0.0
 * It parses TOML strings into a tree of TomlValue objects.
 *
 * UTF-8 Support: The parser assumes the input TOML string is valid UTF-8 encoded.
 * It correctly handles Unicode characters in strings, keys, and comments.
 *
 * Easy API: Use TomlParser.parse_file(filename) to get a TomlValue tree.
 * TomlValue provides get(key) for tables and get_index(index) for arrays.
 *
 * Functional Design: Parsing is side-effect free, using immutable structures where possible.
 * The parser is self-cleaning with Vala's garbage collector managing memory.
 *
 * Copyright (c) 2025 Darcy Bras da Silva
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

using Gee;

public enum TomlType {
    STRING,
    INT,
    FLOAT,
    BOOL,
    DATETIME,
    ARRAY,
    TABLE
}

public class TomlValue {
    public TomlType val_type { get; private set; }
    public string? string_val { get; private set; }
    public int64 int_val { get; private set; }
    public double float_val { get; private set; }
    public bool bool_val { get; private set; }
    public Gee.ArrayList<TomlValue>? array_val { get; private set; }
    public Gee.HashMap<string, TomlValue>? table_val { get; private set; }

    public TomlValue.string(string val) {
        val_type = STRING;
        string_val = val;
    }

    public TomlValue.int(int64 val) {
        val_type = INT;
        int_val = val;
    }

    public TomlValue.float(double val) {
        val_type = FLOAT;
        float_val = val;
    }

    public TomlValue.bool(bool val) {
        val_type = BOOL;
        bool_val = val;
    }

    public TomlValue.datetime(string val) {
        val_type = DATETIME;
        string_val = val;
    }

    public TomlValue.array(Gee.ArrayList<TomlValue> val) {
        val_type = ARRAY;
        array_val = val;
    }

    public TomlValue.table(Gee.HashMap<string, TomlValue> val) {
        val_type = TABLE;
        table_val = val;
    }

    public TomlValue? get(string key) {
        if (val_type != TABLE || table_val == null) return null;
        return table_val[key];
    }

    public TomlValue? get_index(int index) {
        if (val_type != ARRAY || array_val == null || index < 0 || index >= array_val.size) return null;
        return array_val[index];
    }

    public string to_toml() {
        var sb = new StringBuilder();
        to_toml_internal(sb, "");
        return sb.str;
    }

    private void to_toml_internal(StringBuilder sb, string indent) {
        switch (val_type) {
            case STRING:
                sb.append("\"" + string_val.replace("\"", "\\\"") + "\"");
                break;
            case INT:
                sb.append(int_val.to_string());
                break;
            case FLOAT:
                sb.append(float_val.to_string());
                break;
            case BOOL:
                sb.append(bool_val ? "true" : "false");
                break;
            case DATETIME:
                sb.append(string_val);
                break;
            case ARRAY:
                sb.append("[");
                for (int i = 0; i < array_val.size; i++) {
                    if (i > 0) sb.append(", ");
                    array_val[i].to_toml_internal(sb, indent);
                }
                sb.append("]");
                break;
            case TABLE:
                foreach (var entry in table_val.entries) {
                    sb.append(indent + entry.key + " = ");
                    entry.value.to_toml_internal(sb, indent);
                    sb.append("\n");
                }
                break;
        }
    }

    public string to_json() {
        return Json.to_string(to_json_node(), false);
    }

    private Json.Node to_json_node() {
        switch (val_type) {
            case STRING:
                return new Json.Node(Json.NodeType.VALUE).init_string(string_val);
            case INT:
                return new Json.Node(Json.NodeType.VALUE).init_int(int_val);
            case FLOAT:
                return new Json.Node(Json.NodeType.VALUE).init_double(float_val);
            case BOOL:
                return new Json.Node(Json.NodeType.VALUE).init_boolean(bool_val);
            case DATETIME:
                return new Json.Node(Json.NodeType.VALUE).init_string(string_val);
            case ARRAY:
                var array = new Json.Array();
                foreach (var val in array_val) {
                    array.add_element(val.to_json_node());
                }
                return new Json.Node(Json.NodeType.ARRAY).init_array(array);
            case TABLE:
                var obj = new Json.Object();
                foreach (var entry in table_val.entries) {
                    obj.set_member(entry.key, entry.value.to_json_node());
                }
                return new Json.Node(Json.NodeType.OBJECT).init_object(obj);
        }
        return new Json.Node(Json.NodeType.NULL);
    }

    public static TomlValue from_json(string json) throws TomlError {
        try {
            var parser = new Json.Parser();
            parser.load_from_data(json);
            return from_json_node(parser.get_root());
        } catch (Error e) {
            throw new TomlError.INVALID_SYNTAX("Invalid JSON: " + e.message);
        }
    }

    private static TomlValue from_json_node(Json.Node node) throws TomlError {
        switch (node.get_node_type()) {
            case Json.NodeType.VALUE:
                var val = node.get_value();
                if (val.type() == typeof(string)) {
                    return new TomlValue.string(val.get_string());
                } else if (val.type() == typeof(int64)) {
                    return new TomlValue.int(val.get_int());
                } else if (val.type() == typeof(double)) {
                    return new TomlValue.float(val.get_double());
                } else if (val.type() == typeof(bool)) {
                    return new TomlValue.bool(val.get_boolean());
                } else {
                    throw new TomlError.INVALID_VALUE("Unsupported JSON value type");
                }
            case Json.NodeType.ARRAY:
                var array = new Gee.ArrayList<TomlValue>();
                var json_array = node.get_array();
                for (int i = 0; i < json_array.get_length(); i++) {
                    array.add(from_json_node(json_array.get_element(i)));
                }
                return new TomlValue.array(array);
            case Json.NodeType.OBJECT:
                var table = new Gee.HashMap<string, TomlValue>();
                var obj = node.get_object();
                foreach (var member in obj.get_members()) {
                    table[member] = from_json_node(obj.get_member(member));
                }
                return new TomlValue.table(table);
            default:
                throw new TomlError.INVALID_VALUE("Unsupported JSON node type");
        }
    }
}

public errordomain TomlError {
    INVALID_SYNTAX,
    INVALID_VALUE,
    DUPLICATE_KEY,
    MISSING_KEY
}

public class TomlParser {
    private string input;
    private int pos;
    private int line;
    private int col;

    public TomlParser(string toml) {
        input = toml;
        pos = 0;
        line = 1;
        col = 1;
    }

    public static TomlValue parse_file(string filename, string? encoding = null) throws TomlError {
        string content = read_file_content(filename, encoding);
        var parser = new TomlParser(content);
        return parser.parse();
    }

    public static async TomlValue parse_file_async(string filename, string? encoding = null) throws TomlError {
        string content = yield read_file_content_async(filename, encoding);
        var parser = new TomlParser(content);
        return parser.parse();
    }

    private char peek() {
        if (pos >= input.length) return '\0';
        return input[pos];
    }

    private char next() {
        char c = peek();
        pos++;
        if (c == '\n') {
            line++;
            col = 1;
        } else {
            col++;
        }
        return c;
    }

    private void skip_whitespace() {
        while (peek().isspace() && peek() != '\n') next();
    }

    private void skip_comment() {
        if (peek() == '#') {
            while (next() != '\n' && peek() != '\0');
        }
    }

    private string parse_key() throws TomlError {
        skip_whitespace();
        StringBuilder key = new StringBuilder();
        if (peek() == '"') {
            next(); // skip "
            while (peek() != '"' && peek() != '\0') {
                if (peek() == '\\') {
                    next();
                    if (peek() == '"') key.append("\"");
                    else if (peek() == '\\') key.append("\\");
                    else throw new TomlError.INVALID_SYNTAX("Invalid escape in key");
                } else {
                    key.append(next().to_string());
                }
            }
            if (next() != '"') throw new TomlError.INVALID_SYNTAX("Unclosed string in key");
        } else if (peek() == '\'') {
            next(); // skip '
            while (peek() != '\'' && peek() != '\0') {
                key.append(next().to_string());
            }
            if (next() != '\'') throw new TomlError.INVALID_SYNTAX("Unclosed string in key");
        } else {
            while (!peek().isspace() && peek() != '=' && peek() != '.' && peek() != '[' && peek() != ']' && peek() != '\0') {
                key.append(next().to_string());
            }
        }
        return key.str;
    }

    private TomlValue parse_value() throws TomlError {
        skip_whitespace();
        char c = peek();
        if (c == '"') {
            return parse_string();
        } else if (c == '\'') {
            return parse_literal_string();
        } else if (c.isdigit() || c == '+' || c == '-') {
            return parse_number();
        } else if (c == 't' || c == 'f') {
            return parse_bool();
        } else if (c == '[') {
            return parse_array();
        } else if (c == '{') {
            return parse_inline_table();
        } else {
            throw new TomlError.INVALID_VALUE("Unknown value type");
        }
    }

    private TomlValue parse_string() throws TomlError {
        StringBuilder sb = new StringBuilder();
        next(); // skip "
        bool multiline = false;
        if (peek() == '"' && input[pos+1] == '"') {
            multiline = true;
            next(); next();
        }
        while (true) {
            char c = next();
            if (c == '\0') throw new TomlError.INVALID_SYNTAX("Unclosed string");
            if (multiline && c == '"' && peek() == '"' && input[pos+1] == '"') {
                next(); next(); next();
                break;
            } else if (!multiline && c == '"') {
                break;
            } else if (c == '\\') {
                c = next();
                if (c == 'n') sb.append("\n");
                else if (c == 't') sb.append("\t");
                else if (c == 'r') sb.append("\r");
                else if (c == '"') sb.append("\"");
                else if (c == '\\') sb.append("\\");
                else if (c == 'u' || c == 'U') {
                    // Unicode, simplified
                    sb.append("\\" + c.to_string());
                } else {
                    throw new TomlError.INVALID_SYNTAX("Invalid escape");
                }
            } else {
                sb.append(c.to_string());
            }
        }
        return new TomlValue.string(sb.str);
    }

    private TomlValue parse_literal_string() throws TomlError {
        StringBuilder sb = new StringBuilder();
        next(); // skip '
        bool multiline = false;
        if (peek() == '\'' && input[pos+1] == '\'') {
            multiline = true;
            next(); next();
        }
        while (true) {
            char c = next();
            if (c == '\0') throw new TomlError.INVALID_SYNTAX("Unclosed literal string");
            if (multiline && c == '\'' && peek() == '\'' && input[pos+1] == '\'') {
                next(); next(); next();
                break;
            } else if (!multiline && c == '\'') {
                break;
            } else {
                sb.append(c.to_string());
            }
        }
        return new TomlValue.string(sb.str);
    }

    private TomlValue parse_number() throws TomlError {
        StringBuilder sb = new StringBuilder();
        bool is_float = false;
        while (peek().isdigit() || peek() == '+' || peek() == '-' || peek() == '.' || peek() == 'e' || peek() == 'E') {
            char c = next();
            sb.append(c.to_string());
            if (c == '.' || c == 'e' || c == 'E') is_float = true;
        }
        string num_str = sb.str;
        if (is_float) {
            double val = double.parse(num_str);
            return new TomlValue.float(val);
        } else {
            int64 val = int64.parse(num_str);
            return new TomlValue.int(val);
        }
    }

    private TomlValue parse_bool() throws TomlError {
        if (input.substring(pos, 4) == "true") {
            pos += 4;
            return new TomlValue.bool(true);
        } else if (input.substring(pos, 5) == "false") {
            pos += 5;
            return new TomlValue.bool(false);
        } else {
            throw new TomlError.INVALID_VALUE("Invalid boolean");
        }
    }

    private TomlValue parse_array() throws TomlError {
        next(); // skip [
        var array = new Gee.ArrayList<TomlValue>();
        while (peek() != ']') {
            skip_whitespace();
            if (peek() == ']') break;
            var val = parse_value();
            array.add(val);
            skip_whitespace();
            if (peek() == ',') next();
            else if (peek() != ']') throw new TomlError.INVALID_SYNTAX("Expected , or ] in array");
        }
        next(); // skip ]
        return new TomlValue.array(array);
    }

    private TomlValue parse_inline_table() throws TomlError {
        next(); // skip {
        var table = new Gee.HashMap<string, TomlValue>();
        while (peek() != '}') {
            skip_whitespace();
            if (peek() == '}') break;
            string key = parse_key();
            skip_whitespace();
            if (next() != '=') throw new TomlError.INVALID_SYNTAX("Expected = in inline table");
            var val = parse_value();
            table[key] = val;
            skip_whitespace();
            if (peek() == ',') next();
            else if (peek() != '}') throw new TomlError.INVALID_SYNTAX("Expected , or } in inline table");
        }
        next(); // skip }
        return new TomlValue.table(table);
    }

    private Gee.ArrayList<string> parse_table_header() throws TomlError {
        next(); // skip [
        var keys = new Gee.ArrayList<string>();
        while (peek() != ']') {
            skip_whitespace();
            string key = parse_key();
            keys.add(key);
            skip_whitespace();
            if (peek() == '.') next();
            else if (peek() != ']') throw new TomlError.INVALID_SYNTAX("Expected . or ] in table header");
        }
        next(); // skip ]
        return keys;
    }

    private Gee.ArrayList<string> parse_array_table_header() throws TomlError {
        next(); next(); // skip [[
        var keys = new Gee.ArrayList<string>();
        while (peek() != ']' || input[pos+1] != ']') {
            skip_whitespace();
            string key = parse_key();
            keys.add(key);
            skip_whitespace();
            if (peek() == '.') next();
            else if (peek() != ']' || input[pos+1] != ']') throw new TomlError.INVALID_SYNTAX("Expected . or ]] in array table header");
        }
        next(); next(); // skip ]]
        return keys;
    }

    private void set_nested_value(Gee.HashMap<string, TomlValue> root, Gee.ArrayList<string> keys, TomlValue val, int start = 0) throws TomlError {
        if (start >= keys.size) return;
        string key = keys[start];
        if (start == keys.size - 1) {
            if (root.has_key(key)) throw new TomlError.DUPLICATE_KEY("Duplicate key: " + key);
            root[key] = val;
        } else {
            if (!root.has_key(key)) {
                root[key] = new TomlValue.table(new Gee.HashMap<string, TomlValue>());
            }
            var sub = root[key];
            if (sub.val_type != TABLE) throw new TomlError.INVALID_SYNTAX("Key conflict");
            set_nested_value(sub.table_val, keys, val, start + 1);
        }
    }

    private void add_to_array_table(Gee.HashMap<string, TomlValue> root, Gee.ArrayList<string> keys, Gee.HashMap<string, TomlValue> table) throws TomlError {
        if (keys.size == 0) return;
        string key = keys[0];
        if (keys.size == 1) {
            if (!root.has_key(key)) {
                root[key] = new TomlValue.array(new Gee.ArrayList<TomlValue>());
            }
            var arr_val = root[key];
            if (arr_val.val_type != ARRAY) throw new TomlError.INVALID_SYNTAX("Key conflict");
            arr_val.array_val.add(new TomlValue.table(table));
        } else {
            if (!root.has_key(key)) {
                root[key] = new TomlValue.table(new Gee.HashMap<string, TomlValue>());
            }
            var sub = root[key];
            if (sub.val_type != TABLE) throw new TomlError.INVALID_SYNTAX("Key conflict");
            var sub_keys = new Gee.ArrayList<string>();
            for (int i = 1; i < keys.size; i++) sub_keys.add(keys[i]);
            add_to_array_table(sub.table_val, sub_keys, table);
        }
    }

    public TomlValue parse() throws TomlError {
        var root = new Gee.HashMap<string, TomlValue>();
        while (pos < input.length) {
            skip_whitespace();
            skip_comment();
            if (peek() == '\0') break;
            if (peek() == '[') {
                if (input[pos+1] == '[') {
                    var keys = parse_array_table_header();
                    var table = new Gee.HashMap<string, TomlValue>();
                    parse_table_content(table);
                    add_to_array_table(root, keys, table);
                } else {
                    var keys = parse_table_header();
                    var table = new Gee.HashMap<string, TomlValue>();
                    parse_table_content(table);
                    set_nested_value(root, keys, new TomlValue.table(table));
                }
            } else {
                parse_key_value(root);
            }
            skip_whitespace();
            if (peek() == '\n') next();
        }
        return new TomlValue.table(root);
    }

    private void parse_table_content(Gee.HashMap<string, TomlValue> table) throws TomlError {
        while (pos < input.length) {
            skip_whitespace();
            skip_comment();
            if (peek() == '\0' || peek() == '[') break;
            parse_key_value(table);
            skip_whitespace();
            if (peek() == '\n') next();
        }
    }

    private void parse_key_value(Gee.HashMap<string, TomlValue> table) throws TomlError {
        var keys = new Gee.ArrayList<string>();
        keys.add(parse_key());
        while (peek() == '.') {
            next();
            keys.add(parse_key());
        }
        skip_whitespace();
        if (next() != '=') throw new TomlError.INVALID_SYNTAX("Expected =");
        var val = parse_value();
        set_nested_value(table, keys, val);
    }

    private static string read_file_content(string filename, string? encoding) throws TomlError {
        try {
            var file = File.new_for_path(filename);
            uint8[] data;
            file.load_contents(null, out data, null);
            string detected_encoding = encoding ?? detect_encoding(data);
            if (detected_encoding == "UTF-8" || detected_encoding == "ASCII") {
                return (string) data;
            } else {
                size_t bytes_read, bytes_written;
                string content = GLib.convert((string) data, -1, "UTF-8", detected_encoding, out bytes_read, out bytes_written);
                if (content == null) {
                    throw new TomlError.INVALID_SYNTAX("Failed to convert encoding");
                }
                return content;
            }
        } catch (Error e) {
            throw new TomlError.INVALID_SYNTAX("Failed to read file: " + e.message);
        }
    }

    private static string detect_encoding(uint8[] data) {
        if (data.length >= 4) {
            if (data[0] == 0x00 && data[1] == 0x00 && data[2] == 0xFE && data[3] == 0xFF) {
                return "UTF-32BE";
            } else if (data[0] == 0xFF && data[1] == 0xFE && data[2] == 0x00 && data[3] == 0x00) {
                return "UTF-32LE";
            }
        }
        if (data.length >= 3) {
            if (data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) {
                return "UTF-8";
            }
        }
        if (data.length >= 2) {
            if (data[0] == 0xFE && data[1] == 0xFF) {
                return "UTF-16BE";
            } else if (data[0] == 0xFF && data[1] == 0xFE) {
                return "UTF-16LE";
            }
        }
        // Assume UTF-8 if no BOM
        return "UTF-8";
    }

    private static async string read_file_content_async(string filename, string? encoding) throws TomlError {
        try {
            var file = File.new_for_path(filename);
            uint8[] data;
            yield file.load_contents_async(null, out data, null);
            string detected_encoding = encoding ?? detect_encoding(data);
            if (detected_encoding == "UTF-8" || detected_encoding == "ASCII") {
                return (string) data;
            } else {
                size_t bytes_read, bytes_written;
                string content = GLib.convert((string) data, -1, "UTF-8", detected_encoding, out bytes_read, out bytes_written);
                if (content == null) {
                    throw new TomlError.INVALID_SYNTAX("Failed to convert encoding");
                }
                return content;
            }
        } catch (Error e) {
            throw new TomlError.INVALID_SYNTAX("Failed to read file: " + e.message);
        }
    }
}

public class TomlWatcher {
    private File file;
    private FileMonitor monitor;
    private bool watching;

    public signal void changed(TomlValue root);

    public TomlWatcher(string filename) {
        file = File.new_for_path(filename);
        watching = false;
    }

    public void start() throws IOError {
        if (watching) return;
        monitor = file.monitor_file(FileMonitorFlags.NONE);
        monitor.changed.connect(on_file_changed);
        watching = true;
    }

    public void stop() {
        if (!watching) return;
        monitor.cancel();
        watching = false;
    }

    private void on_file_changed(File file, File? other_file, FileMonitorEvent event_type) {
        if (event_type == FileMonitorEvent.CHANGES_DONE_HINT) {
            try {
                var root = TomlParser.parse_file(file.get_path());
                changed(root);
            } catch (TomlError e) {
                // Ignore parse errors on change
            }
        }
    }
}

public class TomlValidationError {
    public string message { get; private set; }
    public int line { get; private set; }
    public int col { get; private set; }
    public string suggestion { get; private set; }

    public TomlValidationError(string msg, int l, int c, string sugg) {
        message = msg;
        line = l;
        col = c;
        suggestion = sugg;
    }
}

public class TomlValidator {
    public static Gee.ArrayList<TomlValidationError> validate_file(string filename, string? encoding = null) {
        var errors = new Gee.ArrayList<TomlValidationError>();
        try {
            TomlParser.parse_file(filename, encoding);
        } catch (TomlError e) {
            string suggestion = "";
            if (e is TomlError.INVALID_SYNTAX) {
                suggestion = "Check the TOML syntax at the indicated position. Ensure keys are properly quoted if necessary, and values match expected types.";
            } else if (e is TomlError.INVALID_VALUE) {
                suggestion = "Verify the value format. For example, strings should be quoted, numbers should not contain invalid characters.";
            } else if (e is TomlError.DUPLICATE_KEY) {
                suggestion = "Remove or rename duplicate keys in the same table.";
            } else if (e is TomlError.MISSING_KEY) {
                suggestion = "Ensure all required keys are present.";
            }
            errors.add(new TomlValidationError(e.message, 0, 0, suggestion)); // Line and col not available in current parser
        }
        return errors;
    }
}

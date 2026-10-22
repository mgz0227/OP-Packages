# Test double for the standard jshn API. Records typed arguments, not plugin logic.
json_init() { printf 'init\0\0\0' > "$AUDIT_JSON_LOG"; }
json_add_boolean() { printf 'boolean\0%s\0%s\0' "$1" "$2" >> "$AUDIT_JSON_LOG"; }
json_add_string() { printf 'string\0%s\0%s\0' "$1" "$2" >> "$AUDIT_JSON_LOG"; }
json_add_array() { printf 'array\0%s\0\0' "$1" >> "$AUDIT_JSON_LOG"; }
json_add_object() { printf 'object\0%s\0\0' "$1" >> "$AUDIT_JSON_LOG"; }
json_close_array() { printf 'close\0\0\0' >> "$AUDIT_JSON_LOG"; }
json_close_object() { printf 'close\0\0\0' >> "$AUDIT_JSON_LOG"; }
json_dump() { "$AUDIT_NODE" "$AUDIT_JSON_ENCODER" "$AUDIT_JSON_LOG"; }
json_load() {
    AUDIT_JSON_INPUT="$1"
    export AUDIT_JSON_INPUT
    "$AUDIT_NODE" -e 'JSON.parse(process.env.AUDIT_JSON_INPUT)' >/dev/null 2>&1
}
json_get_var() {
    # Match jshn assignments without losing embedded newlines or evaluating input.
    eval "$("$AUDIT_NODE" -e '
        const value=JSON.parse(process.env.AUDIT_JSON_INPUT)[process.argv[2]];
        const text=typeof value==="string" ? value : "";
        const quote=String.fromCharCode(39);
        process.stdout.write(process.argv[1]+"="+quote+text.split(quote).join(quote+"\\"+quote+quote)+quote);
    ' "$1" "$2")"
}

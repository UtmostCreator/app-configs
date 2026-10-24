# Reviewed literal route segments may be supplied with --argjson public_path_segments '["payments"]'.
# Default: redact every nonempty segment, including short IDs and encoded identifiers.
def report_path:
  ($ARGS.named | if has("public_path_segments") then .public_path_segments else [] end) as $public
  | if ($public | type) != "array" or any($public[]; type != "string")
       or any($public[]; test("^[A-Za-z][A-Za-z0-9._~-]*\\z") | not)
    then error("public_path_segments must contain reviewed literal route names")
    else split("/") | map(. as $segment |
      if . == "" then ""
      elif $public | index($segment) then $segment
      else ":redacted" end) | join("/") end;

def checked_path:
  if test("^/(?!/)[A-Za-z0-9._~!$&'()*+,;=:@/%-]*\\z") | not
  then error("invalid or unsupported pathname")
  elif (gsub("%[0-9A-Fa-f]{2}"; "") | contains("%"))
  then error("invalid pathname percent escape")
  else report_path end;

# Adapter for a selected Netlify traffic Log Drain JSONL export (not CLI function logs).
# Supported absolute URLs: HTTP(S), ASCII DNS/IPv4 authority, optional userinfo/port.
# Other URL forms fail closed; use a separately reviewed adapter for them.
def traffic_path:
  if test("[\\x00-\\x20\\x7f\\\\]") then error("invalid traffic URL characters")
  elif (gsub("%[0-9A-Fa-f]{2}"; "") | contains("%"))
  then error("invalid traffic URL percent escape")
  else ([try capture("^(?i:https?)://(?:[A-Za-z0-9._~!$&'()*+,;=:%-]+@)?(?<host>[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?)(?::(?<port>[0-9]{1,5}))?(?<path>/[^?#]*)?(?:\\?[^#]*)?(?:#.*)?$")
        catch error("invalid or unsupported absolute traffic URL")] | if length == 1 then .[0] else error("invalid or unsupported absolute traffic URL") end) as $parts
    | if $parts == null then error("invalid or unsupported absolute traffic URL")
      elif ($parts.host | length > 253)
        or ($parts.host | split(".") | any(. == "" or length > 63 or startswith("-") or endswith("-")))
        or (($parts.host | test("^[0-9.]+$")) and
            ($parts.host | split(".") | length != 4 or any(.[]; (tonumber? // 999) > 255 or (length > 1 and startswith("0")))))
        or (($parts.port // "") != "" and (($parts.port | tonumber) < 1 or ($parts.port | tonumber) > 65535))
      then error("invalid traffic URL authority")
      else (($parts.path // "") | if . == "" then "/" else . end | checked_path) end
  end;

if type != "object" then error("expected a traffic object")
elif .log_type != "traffic" or (.status_code | type) != "number"
  or .status_code < 100 or .status_code > 599 or .status_code != (.status_code | floor)
  or (.duration | type) != "number" or .duration < 0
  or (.url | type) != "string" or (.request_id | type) != "string" or .request_id == ""
  or (.timestamp | type) != "string"
then error("missing or invalid traffic-drain fields")
else {schema: "netlify-traffic-drain", request_id, timestamp,
      status: .status_code, path: (.url | traffic_path), duration_ms: .duration,
      path_policy: "reviewed-literal-segments-only"}
end

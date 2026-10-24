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

# Adapter for selected regular-function Log Drain rows. Verify duration units externally.
if type == "object" and .function_type == "standard"
then error("legacy standard function type is unresolved; independent type evidence required")
elif type != "object" then error("expected a function object")
elif .log_type != "functions" or .function_type != "regular"
  or (.status_code | type) != "number" or .status_code < 100 or .status_code > 599
  or .status_code != (.status_code | floor)
  or (.duration | type) != "number" or .duration < 0
  or (.path | type) != "string" or (.request_id | type) != "string" or .request_id == ""
  or (.timestamp | type) != "string" or (.function_name | type) != "string"
then error("missing or invalid regular-function-drain fields")
elif $duration_unit != "ms" and $duration_unit != "us" and $duration_unit != "s"
then error("verified function duration_unit must be ms, us or s")
else {schema: "netlify-function-drain", request_id, timestamp, function_name,
      path_policy: "reviewed-literal-segments-only",
      status: .status_code, path: (.path | split("?")[0] | split("#")[0] | checked_path),
      duration_ms: (.duration * (if $duration_unit == "s" then 1000 elif $duration_unit == "us" then 0.001 else 1 end))}
end

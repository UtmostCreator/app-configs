# Adapter for selected regular-function Log Drain rows. Verify duration units externally.
if type != "object" then error("expected a function object")
elif .log_type != "functions" or (.function_type != "regular" and .function_type != "standard")
  or (.status_code | type) != "number" or .status_code < 100 or .status_code > 599
  or .status_code != (.status_code | floor)
  or (.duration | type) != "number" or .duration < 0
  or (.path | type) != "string" or (.request_id | type) != "string" or .request_id == ""
  or (.timestamp | type) != "string" or (.function_name | type) != "string"
then error("missing or invalid regular-function-drain fields")
elif $duration_unit != "ms" and $duration_unit != "us" and $duration_unit != "s"
then error("verified function duration_unit must be ms, us or s")
else {schema: "netlify-function-drain", request_id, timestamp, function_name,
      status: .status_code, path: (.path | split("?")[0] | split("#")[0]),
      duration_ms: (.duration * (if $duration_unit == "s" then 1000 elif $duration_unit == "us" then 0.001 else 1 end))}
end

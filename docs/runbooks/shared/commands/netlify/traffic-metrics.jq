# Adapter for a selected Netlify traffic Log Drain JSONL export (not CLI function logs).
if type != "object" then error("expected a traffic object")
elif .log_type != "traffic" or (.status_code | type) != "number"
  or .status_code < 100 or .status_code > 599 or .status_code != (.status_code | floor)
  or (.duration | type) != "number" or .duration < 0
  or (.url | type) != "string" or (.request_id | type) != "string" or .request_id == ""
  or (.timestamp | type) != "string"
then error("missing or invalid traffic-drain fields")
else {schema: "netlify-traffic-drain", request_id, timestamp,
      status: .status_code, path: (.url | split("?")[0] | split("#")[0]), duration_ms: .duration}
end

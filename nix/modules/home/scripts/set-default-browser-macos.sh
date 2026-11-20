#!/usr/bin/env bash
# Run in the logged-in user's session, after Homebrew installs Brave.
set -euo pipefail
bundle_id=com.brave.Browser
app='/Applications/Brave Browser.app'
pdf_bundle_id=com.apple.Preview
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[[ -d "$app" ]] || { printf 'Brave is missing: %s\n' "$app" >&2; exit 1; }
"$lsregister" -f "$app"
for scheme in http https; do
  duti -s "$bundle_id" "$scheme"
done
for type in public.html public.xhtml; do
  duti -s "$bundle_id" "$type" all
done
[[ "$(duti -d public.html)" == "$bundle_id" ]] || {
  printf 'Could not set Brave as the default HTML handler\n' >&2
  exit 1
}
for scheme in http https; do
  [[ "$(duti -d "$scheme")" == "$bundle_id" ]] || printf 'Warning: %s is not handled by Brave yet; macOS may be waiting for you to confirm the default browser change\n' "$scheme" >&2
done
duti -s "$pdf_bundle_id" com.adobe.pdf all
[[ "$(duti -d com.adobe.pdf)" == "$pdf_bundle_id" ]] || {
  printf 'Could not set Preview as the default PDF handler\n' >&2
  exit 1
}

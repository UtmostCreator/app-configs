#!/usr/bin/env bash
# Run in the logged-in user's session, after Homebrew installs Brave Beta.
set -euo pipefail
bundle_id=com.brave.Browser.beta
app='/Applications/Brave Browser Beta.app'
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[[ -d "$app" ]] || { printf 'Brave Beta is missing: %s\n' "$app" >&2; exit 1; }
"$lsregister" -f "$app"
for scheme in http https; do
  duti -s "$bundle_id" "$scheme"
done
for type in public.html public.xhtml com.adobe.pdf; do
  duti -s "$bundle_id" "$type" all
done
[[ "$(duti -d public.html)" == "$bundle_id" ]] || {
  printf 'Could not set Brave Beta as the default HTML handler\n' >&2
  exit 1
}

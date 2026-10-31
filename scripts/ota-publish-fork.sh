#!/usr/bin/env bash
# Publishes a "Signed install" run from this fork: downloads the sealed artifact,
# unseals it with the private key from 1Password, writes the manifest and install
# page, and serves it from the host. Needs gh, op, openssl and curl.
#
#   scripts/ota-publish-fork.sh <run-id>
set -euo pipefail

repo=${APOLLO_OTA_REPO:-Dragooon/Apollo-Reborn}
root=${APOLLO_OTA_ROOT:-/var/lib/cc-ota/cc/apollo}
url_path=${APOLLO_OTA_URL_PATH:-cc/apollo}
key_ref=${APOLLO_OTA_KEY_REF:-op://Shared/cc-controller-ios install key/notesPlain}
keep_builds=3

run_id=${1:-}
[[ "$run_id" =~ ^[0-9]+$ ]] || { printf 'usage: %s <run-id>\n' "$0" >&2; exit 2; }

host=${APOLLO_OTA_HOST:-$(tailscale status --json | python3 -I -c 'import json, sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')}
mkdir -p "$root"
[[ -w "$root" ]] || { printf '%s is not writable\n' "$root" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
gh run download "$run_id" -R "$repo" -n install-package -D "$work/sealed"
mkdir "$work/package"
openssl pkeyutl -decrypt -inkey <(op read "$key_ref") -pkeyopt rsa_padding_mode:oaep \
  -in "$work/sealed/install.key.enc" -out "$work/key"
openssl enc -d -aes-256-cbc -pbkdf2 -md sha256 -pass "file:$work/key" -in "$work/sealed/install.tar.enc" \
  | tar -C "$work/package" --no-same-owner --no-same-permissions -xf -

package_value() {
  sed -n "s/^$1=//p" "$work/package/package.env"
}
bundle=$(package_value bundle)
version=$(package_value version)
bundle_version=$(package_value bundle_version)
sha=$(package_value sha)
built=$(package_value built)
[[ "$bundle" =~ ^[A-Za-z0-9.-]+$ ]] || { printf 'bad bundle ID in the package: %s\n' "$bundle" >&2; exit 1; }
[[ "$version" =~ ^[0-9A-Za-z.-]+$ ]] || { printf 'bad version in the package: %s\n' "$version" >&2; exit 1; }
[[ "$bundle_version" =~ ^[0-9A-Za-z.-]+$ ]] || { printf 'bad build in the package: %s\n' "$bundle_version" >&2; exit 1; }
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { printf 'bad commit in the package: %s\n' "$sha" >&2; exit 1; }
[[ "$built" =~ ^[0-9:\ -]+UTC$ ]] || { printf 'bad build date in the package: %s\n' "$built" >&2; exit 1; }
[[ -f "$work/package/Apollo-Reborn.ipa" ]] || { printf 'the package has no IPA\n' >&2; exit 1; }
[[ ! -e "$root/$run_id" ]] || { printf 'run %s is already published\n' "$run_id" >&2; exit 2; }

base_url="https://$host/$url_path/$run_id"
staging="$root/.staging-$run_id"
mkdir "$staging"
cp "$work/package/Apollo-Reborn.ipa" "$staging/"
cat > "$staging/manifest.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>$base_url/Apollo-Reborn.ipa</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>$bundle</string>
        <key>bundle-version</key>
        <string>$bundle_version</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>Apollo Reborn</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST
cat > "$staging/index.html" <<HTML
<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Apollo Reborn $version</title>
<p><a style="font: bold 2em system-ui" href="itms-services://?action=download-manifest&url=$base_url/manifest.plist">Install Apollo Reborn</a></p>
<p>Version $version, commit ${sha:0:7}</p>
<p>Build date: $built</p>
HTML
chmod -R a+rX "$staging"
mv "$staging" "$root/$run_id"
cp "$root/$run_id/index.html" "$root/.latest.html"
chmod a+r "$root/.latest.html" "$root"
mv "$root/.latest.html" "$root/latest.html"

for old in $(find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -E '^[0-9]+$' | sort -rn | tail -n +$((keep_builds + 1))); do
  rm -rf -- "${root:?}/$old"
  printf 'deleted old build %s\n' "$old"
done

address=$(tailscale ip -4)
for path in "$run_id/manifest.plist" "$run_id/Apollo-Reborn.ipa" latest.html; do
  code=$(curl -s -o /dev/null -m 60 -w '%{http_code}' --resolve "$host:443:$address" "https://$host/$url_path/$path")
  [[ "$code" == 200 ]] || { printf 'https://%s/%s/%s returned %s\n' "$host" "$url_path" "$path" "$code" >&2; exit 1; }
done
printf 'published run %s: https://%s/%s/latest.html\n' "$run_id" "$host" "$url_path"

#!/usr/bin/env bash
# Prepares a GitHub macOS runner to sign the iOS or macOS app (release.yml).
#
#   bash tool/ci/apple_signing.sh ios|macos
#
# Reads from the environment:
#   CERT_P12_BASE64   the signing certificate and its private key, as a .p12
#   CERT_PASSWORD     the .p12's password
#   PROFILE_BASE64    the provisioning profile for com.jaival.taskly
#
# Imports the certificate into a keychain of its own, installs the profile,
# and switches the Runner target's Release configuration to manual signing
# with them. Nothing here is committed: the runner is thrown away afterwards.
#
# Writes to $GITHUB_OUTPUT: team, profile (its name), identity (the
# certificate's common name) and method (the export method that fits the
# profile, for ExportOptions.plist).
set -euo pipefail

platform=$1
work=$RUNNER_TEMP/signing
mkdir -p "$work"

# A keychain of its own, unlocked for the rest of the job, so codesign never
# waits for a password dialog that nobody can answer.
keychain=$work/signing.keychain-db
keychain_password=$(openssl rand -hex 24)
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
echo "$CERT_P12_BASE64" | base64 --decode > "$work/cert.p12"
security import "$work/cert.p12" -k "$keychain" -P "$CERT_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild
security set-key-partition-list -S apple-tool:,apple: -s \
  -k "$keychain_password" "$keychain" > /dev/null
# Searched first, then the runner's own keychains. One word per keychain.
# shellcheck disable=SC2046
security list-keychains -d user -s "$keychain" \
  $(security list-keychains -d user | tr -d '"')
rm "$work/cert.p12"

identity=$(security find-identity -v -p codesigning "$keychain" \
  | sed -n 's/.*"\(.*\)"/\1/p' | head -n 1)
if [ -z "$identity" ]; then
  echo "::error::No signing identity in the certificate. Export it from Keychain Access together with its private key."
  exit 1
fi

# Xcode 16 looks for profiles in UserData, older versions in MobileDevice.
case $platform in
  ios) extension=mobileprovision ;;
  macos) extension=provisionprofile ;;
  *) echo "usage: $0 ios|macos" >&2; exit 2 ;;
esac
echo "$PROFILE_BASE64" | base64 --decode > "$work/profile"
security cms -D -i "$work/profile" > "$work/profile.plist"
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$work/profile.plist" 2>/dev/null; }
uuid=$(plist UUID)
profile=$(plist Name)
team=$(plist 'TeamIdentifier:0')
for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
           "$HOME/Library/MobileDevice/Provisioning Profiles"; do
  mkdir -p "$dir"
  cp "$work/profile" "$dir/$uuid.$extension"
done

# What kind of profile it is decides how the app can be exported.
if [ "$platform" = macos ]; then
  method=developer-id
elif plist ProvisionsAllDevices > /dev/null; then
  method=enterprise
elif plist ProvisionedDevices > /dev/null; then
  if [ "$(plist Entitlements:get-task-allow)" = true ]; then
    method=debugging
  else
    method=release-testing
  fi
else
  method=app-store-connect
fi

ruby "$(dirname "$0")/sign_xcode_target.rb" "$platform/Runner.xcodeproj" \
  "$team" "$profile" "$identity"

echo "Signing as \"$identity\" (team $team) with profile \"$profile\", exported as $method."
{
  echo "team=$team"
  echo "profile=$profile"
  echo "identity=$identity"
  echo "method=$method"
} >> "$GITHUB_OUTPUT"

#!/usr/bin/env bash
# Archive the app and upload it to App Store Connect. Run on a Mac, from the repo root:
#   ./scripts/release-appstore.sh
# Needs: Xcode signed in to the Apple account of team SPLML3CN76 (Xcode > Settings > Accounts),
# and Secrets.xcconfig present (gitignored). Uses automatic signing.
# The build lands in App Store Connect > TestFlight after Apple's processing (10-30 min);
# submitting it for review is still done by hand in App Store Connect.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f Secrets.xcconfig ] || { echo "Secrets.xcconfig is missing (SUPABASE_URL, SUPABASE_ANON_KEY, REVENUECAT_IOS_KEY)." >&2; exit 1; }
./scripts/check-build-number-sync.sh
python3 scripts/check-pricing-consistency.py >/dev/null

ARCHIVE=".build/EcrinVirtuel.xcarchive"
OPTS=".build/ExportOptions.plist"
mkdir -p .build
cat > "$OPTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>SPLML3CN76</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

xcodebuild archive -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates | grep -E "error:|warning: .*signing|ARCHIVE SUCCEEDED|ARCHIVE FAILED" || true
[ -d "$ARCHIVE" ] || { echo "Archive failed." >&2; exit 1; }

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTS" \
  -exportPath .build/export -allowProvisioningUpdates | grep -E "error:|EXPORT SUCCEEDED|EXPORT FAILED|Upload succeeded" || true
echo "Done. Check App Store Connect > TestFlight in 10 to 30 minutes."

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash Tools/setup-sparkle.sh
mkdir -p .build/ModuleCache DentalLab.app/Contents/MacOS DentalLab.app/Contents/Resources
cp Resources/DentalLab.icns DentalLab.app/Contents/Resources/
xcrun clang -c Sources/CryptoSupport/CryptoSupport.c -I Sources/CryptoSupport/include -o .build/CryptoSupport.o
xcrun swiftc -D DIRECT_BUILD -module-cache-path .build/ModuleCache -import-objc-header Sources/CryptoSupport/include/CryptoSupport.h -F Vendor -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks -O -parse-as-library Sources/DentalLab/*.swift .build/CryptoSupport.o -o DentalLab.app/Contents/MacOS/DentalLab
mkdir -p DentalLab.app/Contents/Frameworks
ditto Vendor/Sparkle.framework DentalLab.app/Contents/Frameworks/Sparkle.framework
cat > DentalLab.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>DentalLab</string><key>CFBundleIdentifier</key><string>it.dentallab.local</string><key>CFBundleIconFile</key><string>DentalLab.icns</string><key>CFBundleName</key><string>DentalLab</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.4.0</string><key>CFBundleVersion</key><string>4</string><key>SUFeedURL</key><string>https://github.com/yn7wvz64hj-oss/DentalLab/releases/latest/download/appcast.xml</string><key>SUPublicEDKey</key><string>zbQAUlVRWlxh+c5Za5FBPLdgtuLwGnVXok0nv8QffNg=</string><key>SUEnableAutomaticChecks</key><false/><key>SUAllowsAutomaticUpdates</key><false/><key>SUVerifyUpdateBeforeExtraction</key><true/><key>SURequireSignedFeed</key><true/><key>SUSignedFeedFailureExpirationInterval</key><integer>0</integer><key>LSMinimumSystemVersion</key><string>13.0</string><key>NSCalendarsUsageDescription</key><string>Sincronizzare le consegne nel calendario scelto.</string><key>NSCalendarsFullAccessUsageDescription</key><string>Creare e aggiornare le consegne DentalLab nel calendario scelto, riconoscendo i propri eventi senza modificare gli altri.</string><key>NSHighResolutionCapable</key><true/><key>NSFaceIDUsageDescription</key><string>Sbloccare l’archivio del laboratorio.</string></dict></plist>
PLIST
codesign --force --sign - DentalLab.app

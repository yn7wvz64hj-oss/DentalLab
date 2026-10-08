#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d Vendor/Sparkle.framework && -x Vendor/bin/sign_update ]]; then exit 0; fi
mkdir -p .build/sparkle Vendor/bin
curl --fail --location --proto '=https' --tlsv1.2 'https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz' --output .build/sparkle.tar.xz
printf '%s  %s\n' 'c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c' '.build/sparkle.tar.xz' | shasum -a 256 -c -
tar -xf .build/sparkle.tar.xz -C .build/sparkle
ditto .build/sparkle/Sparkle.framework Vendor/Sparkle.framework
cp .build/sparkle/bin/sign_update Vendor/bin/
cp .build/sparkle/LICENSE Vendor/SPARKLE-LICENSE

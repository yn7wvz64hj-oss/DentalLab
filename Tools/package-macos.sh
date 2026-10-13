#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/package-root dist/installer
ditto DentalLab.app .build/package-root/DentalLab.app
pkgbuild --analyze --root .build/package-root .build/package-components.plist
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' .build/package-components.plist
pkgbuild --root .build/package-root --component-plist .build/package-components.plist --identifier it.dentallab.installer --version 0.7.1 --install-location /Applications .build/DentalLab-component.pkg
productbuild --package .build/DentalLab-component.pkg dist/installer/DentalLab-Installer-macOS-Intel.pkg
pkgutil --expand-full dist/installer/DentalLab-Installer-macOS-Intel.pkg .build/package-check
python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
root = Path('.build/package-check')
info = list(root.rglob('PackageInfo'))
assert len(info) == 1
assert ET.parse(info[0]).getroot().attrib['install-location'] == '/Applications'
apps = list(root.glob('**/Payload/DentalLab.app/Contents/MacOS/DentalLab'))
assert len(apps) == 1
assert list(root.glob('**/Payload/DentalLab.app/Contents/Resources/DentalLab.icns'))
assert not list(root.rglob('preinstall')) and not list(root.rglob('postinstall'))
print('PASS: installer payload, destination, icon, and absence of data scripts.')
PY

#!/usr/bin/env python3
"""Build a signed Sparkle archive and appcast. The private key is never packaged."""
import argparse, pathlib, plistlib, subprocess, tempfile, xml.etree.ElementTree as ET
parser = argparse.ArgumentParser()
parser.add_argument('--key', required=True, type=pathlib.Path, help='Private Ed25519 signing key file, outside the project')
parser.add_argument('--output', required=True, type=pathlib.Path)
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
key = args.key.resolve()
if key == root or root in key.parents:
    parser.error('Keep the private key outside the project and release directory')
output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
app = root / 'DentalLab.app'
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
with tempfile.TemporaryDirectory(prefix='DentalLab-release-') as cache:
    public_key = subprocess.check_output(['xcrun', 'swift', '-module-cache-path', cache, str(root / 'Tools/update-public-key.swift'), str(key)], text=True).strip()
if public_key != info.get('SUPublicEDKey'):
    parser.error('The signing key does not match the public key embedded in the app')
version = info['CFBundleShortVersionString']
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
archive = output / ('DentalLab-' + version + '-mac.zip')
subprocess.run(['ditto', '--norsrc', '--noextattr', '-c', '-k', '--keepParent', str(app), str(archive)], check=True)
signer = root / 'Vendor/bin/sign_update'
signature = subprocess.check_output([str(signer), '--ed-key-file', str(key), '-p', str(archive)], text=True).strip()
subprocess.run([str(signer), '--verify', '--ed-key-file', str(key), str(archive), signature], check=True)
namespace = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', namespace)
rss = ET.Element('rss', version='2.0'); channel = ET.SubElement(rss, 'channel')
ET.SubElement(channel, 'title').text = 'DentalLab per Mac'
item = ET.SubElement(channel, 'item')
ET.SubElement(item, 'title').text = 'DentalLab ' + version
ET.SubElement(item, '{'+namespace+'}version').text = info['CFBundleVersion']
ET.SubElement(item, '{'+namespace+'}shortVersionString').text = version
ET.SubElement(item, '{'+namespace+'}minimumSystemVersion').text = info['LSMinimumSystemVersion']
ET.SubElement(item, 'description').text = 'Nuova versione DentalLab. Consulta le note della release su GitHub e salva un backup prima di installare.'
ET.SubElement(item, 'enclosure', {
    'url': 'https://github.com/yn7wvz64hj-oss/DentalLab/releases/download/v'+version+'/'+archive.name,
    'length': str(archive.stat().st_size), 'type': 'application/octet-stream', '{'+namespace+'}edSignature': signature})
feed = output / 'appcast.xml'
ET.ElementTree(rss).write(feed, encoding='utf-8', xml_declaration=True)
subprocess.run([str(signer), '--ed-key-file', str(key), str(feed)], check=True)
subprocess.run([str(signer), '--verify', '--ed-key-file', str(key), str(feed)], check=True)
print('Release pronta:', archive.name, 'e appcast.xml')

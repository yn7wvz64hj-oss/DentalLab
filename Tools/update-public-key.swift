import Foundation
import CryptoKit
let encoded = try String(contentsOfFile: CommandLine.arguments[1]).trimmingCharacters(in: .whitespacesAndNewlines)
guard let seed = Data(base64Encoded: encoded), seed.count == 32 else { fputs("Formato chiave privata non valido\n", stderr); exit(1) }
let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
print(key.publicKey.rawRepresentation.base64EncodedString())

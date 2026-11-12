/* Checks a signed update the way an installed app will, using the public key inside the built app.
   A release stops here if the signing secret and the app's public key do not belong together,
   because installed copies would refuse every update signed with the wrong key.

   Usage: swift scripts/verify-update.swift <file> <signature> <public key> */

import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
    let signature = Data(base64Encoded: arguments[2]),
    let publicKey = Data(base64Encoded: arguments[3])
else {
    print("Give a file, a base64 signature, and a base64 public key.")
    exit(2)
}

let file = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
guard key.isValidSignature(signature, for: file) else {
    print("The signature does not match the app's public key.")
    exit(1)
}
print("The signature matches the app's public key.")

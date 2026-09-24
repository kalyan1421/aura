# Apple root certificates (App Store signed data)

Trust anchors for verifying App Store JWS (`signedPayload` of App Store Server Notifications V2, `signedTransactionInfo`,
`signedRenewalInfo`, and StoreKit 2 `jwsRepresentation`). The `x5c` chain in each JWS header must end at one of these.

| File | Source | SHA-256 (DER) | Expires |
|---|---|---|---|
| `AppleRootCA-G3.cer` | https://www.apple.com/certificateauthority/AppleRootCA-G3.cer | `63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179` | 2039-04-30 |
| `AppleRootCA-G2.cer` | https://www.apple.com/certificateauthority/AppleRootCA-G2.cer | `c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050` | 2039-04-30 |

Downloaded 24 Sep 2026 from Apple PKI (https://www.apple.com/certificateauthority/). The fingerprints match the ones
Apple publishes on that page. App Store signing chains today end at **G3** (ECDSA P-256); G2 is kept because Apple's own
App Store Server Library trusts it too.

`../apple-roots.ts` embeds the same bytes (base64) so the compiled server needs no extra files;
`test/unit/billing.apple-jws.spec.ts` fails if the two ever differ or a fingerprint changes. To rotate: replace the
file, regenerate `apple-roots.ts` (`base64` of the DER) and update the table above.

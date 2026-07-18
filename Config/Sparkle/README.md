# Sparkle configuration

NotchRelay uses Sparkle 2.9.4 with EdDSA-signed update archives and a signed appcast.

Public EdDSA key:

```
jdfVgATZX2FxlG7vDWmIFurSoELcZ/qJbnkQbaWg4H4=
```

The private key is stored in the maintainer's macOS Keychain under the `notchrelay` account and in the GitHub Actions `SPARKLE_PRIVATE_KEY` secret. It must never be committed. The app reads its feed from the `appcast.xml` asset attached to the latest GitHub release.

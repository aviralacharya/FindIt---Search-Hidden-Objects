# Current branding/policy local candidates

**6 November 2026 · version 1.0.0+1 · not a Play release**

- `qa/FindIt-Hidden-Objects-1.0.0-QA.apk`: separate QA package, development-signed, launcher **FindIt Hidden QA**.
- `production-unsigned/FindIt-Hidden-Objects-1.0.0-UNSIGNED.apk`: production package, genuinely unsigned, launcher **FindIt Hidden**. It cannot be installed normally or uploaded as a store release.
- Each directory contains the APK's matching strict inspection, six R8 evidence files, and `SHA256SUMS.txt`. The top-level checksum list covers this revision only. Android binaries remain excluded from Git.

Both APKs include the supplied green magnifying-glass/star/leaf icon, the current 11-section link-free offline policy, 60 hidden-only levels, and the latest layout fixes. Static inspection passed for bundled source assets, all 15 launcher PNG variants and adaptive/themed layers, backup/transfer XML, identity, permissions, signature state, absent advertising/test-plugin references, and applicable 64-bit 16 KB packaging alignment. This is not real-device/runtime QA.

The earlier APKs outside `revisions/` are preserved with their older matching evidence; they predate these branding/policy/layout changes. See `release/local/2026-11-06/README.md` from the project root for current test and preservation evidence.

**There is no final signed production AAB yet.** Publish the root `privacy-policy.html` through GitHub Pages, supply its actual rendered HTTPS URL, confirm the secure key backup and publisher review, and use `python tool/build_signed_aab.py --dialog` for fresh masked entry of the **existing** key's password. Never recreate or publish the private key. Device QA and Play Console/legal review remain required; no upload or publication has been performed.

# Publish the privacy policy on GitHub Pages

The ready-to-host, self-contained page is **`privacy-policy.html` in the project root**. It uses no URLs, hyperlinks, scripts, cookies, trackers, external fonts, or image dependencies. The required developer email is plain text. You may copy only that file into a public GitHub Pages repository; the Flutter app does not need to be publicly hosted.

## One policy source

**Edit only `assets/legal/privacy-policy.json`.** The app loads that asset offline, and the HTML generator uses exactly the same headings, paragraphs, bullets, identity, contact information, and revision date. Do not edit the HTML or write a second policy in Dart.

```powershell
python tool/generate_privacy_policy.py --write
python tool/generate_privacy_policy.py --check --output verification/privacy-policy-parity.json
```

Both renderers deliberately reject links and URL text. Provider names and their data practices remain disclosed without outbound links. The live hosting URL is a separate release/Play Console input, not policy content.

## Before publishing

- Review the policy against the release's actual behavior and your legal obligations. It is a prepared disclosure, not legal advice.
- Confirm **Abiral Acharya** and **abiralacharya80@gmail.com** are the correct public developer/contact details. They match the app's existing configuration.
- Confirm the new listing is for `abiral.mobile.findithiddenobjects`, launcher name **FindIt Hidden**, version `1.0.0` / code `1`.
- Keep `PACK_INDEX_URL` empty, with no ads, analytics, purchases, or remote pack server for this release. If those practices change, update the canonical policy and store disclosures, then regenerate the HTML.
- Update the policy date when approving a later revision.

## Hosting

1. Copy `privacy-policy.html` into the root of your selected GitHub Pages publishing directory. You may instead rename the copy to `index.html` in a dedicated policy repository.
2. Enable Pages for that directory in the selected repository. Use a repository/domain you own; no repository, commit, push, or deployment has been made by this preparation.
3. Open the resulting **actual HTTPS page URL** in a signed-out/incognito browser. It must load the full policy without login, download prompts, geography restrictions, or authentication.
4. Use the rendered Pages URL, **not** a `github.com/.../blob/...` source page or a raw-file download URL.
5. Send the live URL back for the final build, and enter exactly that same URL in Play Console.

## Final build configuration

Copy `config/production.example.json` to the ignored local `config/production.json`. Set `PRIVACY_POLICY_URL` to the verified live URL; preserve `APP_ENV=production`, `BUILD_STAGE=final`, and the empty `PACK_INDEX_URL`.

The final signed AAB intentionally cannot be built with an empty, placeholder, local, or non-HTTPS policy URL. Hosting the policy later means the AAB must be built **after** the actual URL is available. Do not weaken this gate or publish an unsigned/QA candidate.

Alternatively, run `python tool/build_signed_aab.py --dialog` from this project's root after hosting. It verifies the complete live HTML, asks for the existing dedicated key's password through native masked input, and creates the ignored final configuration only if absent. Different existing configuration is not overwritten. It reuses the key, builds and strictly inspects the local AAB, and retains matching public evidence; it never creates another key, saves a password, uploads, or publishes. Confirm the secure key backup and publisher review in the dialog. Android/device QA and Play Console/legal checks remain required before publication.

Keep `.local-signing/`, keystores, signing passwords, `android/key.properties`, and private configuration out of the hosting repository. Only the public `.pem` upload certificate may be shared when a signing workflow needs it; never share the private keystore.

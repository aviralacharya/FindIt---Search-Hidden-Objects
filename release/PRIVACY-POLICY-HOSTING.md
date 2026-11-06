# Maintain the privacy policy on GitHub Pages

The self-contained page is **`privacy-policy.html` in the project root**. It uses no URLs, hyperlinks, scripts, cookies, trackers, external fonts, or image dependencies. The required developer email is plain text. GitHub's hosting infrastructure can still process ordinary website requests as disclosed in the policy; a tracker-free HTML file does not mean the host receives no request data.

- **Repository:** https://github.com/aviralacharya/FindIt-Search-Hidden-Objects
- **Canonical public policy:** https://aviralacharya.github.io/FindIt-Search-Hidden-Objects/privacy-policy
- **Pages source:** `main` branch, repository root `/`, with HTTPS enforced.

The canonical path is `privacy-policy` without a file extension; GitHub Pages serves the generated `privacy-policy.html` at that path. Hosting the policy does not require deploying the playable Flutter web preview.

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

## Deploying a policy revision

1. Update only `assets/legal/privacy-policy.json`, including its policy revision/date when appropriate. Regenerate `privacy-policy.html` and run the parity check above.
2. Review the Git diff and stage only approved public files. Commit and push the shared policy source, generated HTML, and related documentation/tests to `main`. Never publish signing material or local production configuration.
3. Confirm **Settings → Pages** still publishes `main` from `/` with HTTPS enforced. Wait for the Pages deployment of that commit to succeed.
4. Open the **canonical HTTPS URL above** in a signed-out/incognito browser. It must return the full rendered policy without login, download prompts, geography restrictions, or authentication, and its HTML must match the current generated file.
5. Use that exact extensionless URL in final release configuration and Play Console, **not** a `github.com/.../blob/...` source page, raw-file download, or the previous triple-hyphen Pages path.

### Repository-name migration

The previous repository name was `FindIt---Search-Hidden-Objects`. The canonical name is now `FindIt-Search-Hidden-Objects`. GitHub redirects ordinary repository Git operations after a rename, but **GitHub Pages project URLs are not automatically redirected**. Update existing policy references and verify the new page before using it in a release. Keep local Git remotes on the canonical repository:

```sh
git remote set-url origin https://github.com/aviralacharya/FindIt-Search-Hidden-Objects.git
```

## Final build configuration

Copy `config/production.example.json` to the ignored local `config/production.json` if no conflicting final configuration exists. After verifying the live page, set `PRIVACY_POLICY_URL` to `https://aviralacharya.github.io/FindIt-Search-Hidden-Objects/privacy-policy`; preserve `APP_ENV=production`, `BUILD_STAGE=final`, and the empty `PACK_INDEX_URL`. No signing passwords belong in either configuration file.

The final signed AAB intentionally cannot be built with an empty, placeholder, local, or non-HTTPS policy URL. Build it **after** the canonical URL serves the current wording. The app and policy remain **1.0.0** because nothing has been released. Existing APK candidates and older captures are pre-update validation snapshots, so they must not be presented as freshly rebuilt or reinspected. Do not weaken release gates or publish an unsigned/QA candidate.

Alternatively, run `python tool/build_signed_aab.py --dialog` from this project's root after hosting. It verifies the complete live HTML, asks for the existing dedicated key's password through native masked input, and creates the ignored final configuration only if absent. Different existing configuration is not overwritten. It reuses the key, builds and strictly inspects the local AAB, and retains matching public evidence; it never creates another key, saves a password, uploads, or publishes. Confirm the secure key backup and publisher review in the dialog. Android/device QA and Play Console/legal checks remain required before publication.

Keep `.local-signing/`, keystores, signing passwords, `android/key.properties`, and private configuration out of the hosting repository. Only the public `.pem` upload certificate may be shared when a signing workflow needs it; never share the private keystore.

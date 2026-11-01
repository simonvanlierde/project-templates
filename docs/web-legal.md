# Legal pages: tips

A rendered web app serves three pages from its `docs/` folder: `accessibility.md` at `/accessibility`, `privacy.md` at `/privacy`, and, for apps with accounts or uploads, `terms.md` at `/terms`. Every page links to these from its footer.
[Legal pages](usage.md#legal-pages) in the usage guide explains how the app compiles the pages and which tests verify them.

These tips help keep your pages accurate, but they are not formal legal advice. For high-stakes applications, consult a qualified lawyer or privacy officer.

## Fill in every TODO

The template populates initial details: app name, address, email, and generation date. Remaining sections are marked TODO. The `just ts-e2e` suite fails until all TODO markers are removed. Keep these pages updated alongside any code changes that affect their accuracy.

## Write for the person using the app

Users open privacy and accessibility pages to find clear answers: where their data goes, how to delete it, whether the app is usable with assistive technology, and who to contact. State these facts directly in plain language.

- **Lead with facts:** Start the privacy page with what data is stored, where it lives, and whether anything leaves the device.
- **Use user-facing terms:** Say "the books on your list", not "persisted entities"; "Settings, then **Delete all data**", not "invoking the deletion handler".
- **Omit internal implementation details:** Test file names and CI job names do not belong on public legal pages.
- **Explain legal grounds plainly:** "We log requests to keep the service running securely (legitimate interest)" is clearer than dense regulatory jargon.
- **Keep sentences short:** State one idea per sentence.
- **Preserve test anchors:** Do not remove headings, email contacts, the accessibility conformance status sentence, the response timeframe, or the "Last reviewed" date.

Example privacy statement for an app storing data locally:

```markdown
# Privacy statement

shelf keeps your reading list on your device. It is never sent to us or anyone else. shelf has no accounts, cookies, or analytics.

This page covers shelf at [shelf.example.org](https://shelf.example.org). Ada Lovelace runs shelf and is responsible for it. "We" on this page means Ada Lovelace.

## What shelf stores on your device

shelf saves data in browser local storage only after you add an item:

- The books on your list and your current page numbers.
- Your preferences: theme and language.

## How to delete it

- In shelf, open Settings and select **Delete all data**.
- Or clear this site's storage in your browser settings.
```

## Who is responsible

- **Personal projects:** You are the data controller. Put your name and email on the privacy statement.
- **Organizational apps:** The organization is the controller. Name the entity, link to its primary privacy policy, and have its privacy officer review the text before launch.
- **EU public-sector sites:** Under the EU Web Accessibility Directive ((EU) 2016/2102), public bodies must publish a formal accessibility statement based on EN 301 549 (aligned with WCAG). Required sections include:
  - Compliance status: "fully compliant", "partially compliant", or "not compliant".
  - Non-accessible content: listed by cause (non-compliance, disproportionate burden, or excluded scope) with accessible alternatives.
  - Preparation details: evaluation method and last review date.
  - Feedback mechanism: contact details for reporting accessibility barriers.
  - Enforcement procedure: link to the relevant national enforcement body.

  In the Netherlands, public bodies use the government wizard at [toegankelijkheidsverklaring.nl](https://www.toegankelijkheidsverklaring.nl/). Link to that entry from "About this statement".

## Accessibility statement

- Keep claims verifiable against repository code: tests in `tests/e2e/`, rules in `biome.json`, and CSS styles. Move resolved issues from "Known problems" to "How we check" within the same PR.
- Conformance status remains "not assessed" until every WCAG 2.2 Level A and AA criterion is evaluated in `docs/accessibility-assessment.md`. Mark status as "partially conformant" only after all 55 criteria are recorded, and list failing criteria under "Known problems".
- The test suite rejects "fully conformant" without a verified third-party audit.
- Review statements annually; tests fail if "Last reviewed" exceeds 400 days.
- Each known problem must list a user workaround and a target fix date or "No fix planned", referencing the WCAG criterion code.

## Privacy statement

- Document purpose, legal basis, and retention period for all stored data, including server logs and user accounts.
- Update "Last updated" with each modification.
- Keep Cloudflare Web Analytics disabled for Cloudflare Pages projects. The bundled script violates the template's Content-Security-Policy (`script-src 'self'`).
- Verify post-deployment headers to ensure no unexpected cookies are set:

  ```sh
  curl -sI <site_url> | grep -i set-cookie
  ```

- Name all third-party network services. Loading external fonts, scripts, or images shares the visitor's IP address. `tests/e2e/privacy.spec.ts` fails if unlisted third-party origins are contacted.

## Cookies and other storage

- **Scope:** Regulations cover all client-side storage mechanisms (`localStorage`, `sessionStorage`, IndexedDB, and cookies) once data is transmitted off the device.
- **Consent exemptions:** Storage strictly necessary to deliver a feature explicitly requested by the user—such as form state, shopping carts, or local preferences—does not require consent.
- **No consent banner by default:** Rendered apps set no cookies and write no client storage before user action. The `privacy.spec.ts` test enforces this on initial load.
- **Analytics:** Privacy-focused first-party analytics (such as self-hosted Plausible or Matomo) that do not track across sites require no consent banner if configured without cookies, but must be documented in the privacy statement.
- **Third-party origins:** If you integrate external services or analytics, add their domains to `OTHER_ORIGINS` in `tests/e2e/privacy.spec.ts` and update `script-src` and `connect-src` in `public/_headers`. Cross-site tracking or advertising scripts require a consent banner before loading.

## Terms of use

Only apps with user accounts, content uploads, or paid services require terms of use. Keep terms concise and aligned with the privacy statement: clarify content ownership, license grants, user obligations, and account termination procedures. Free tools without accounts rely on the software license and standard disclaimer in the privacy statement.

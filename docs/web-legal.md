# Legal pages: tips

A rendered web app serves three pages from its `docs/` folder: `accessibility.md` at
`/accessibility`, `privacy.md` at `/privacy`, and, for an app with accounts or uploads,
`terms.md` at `/terms`. Every page links them from its footer. This page lives in the
[project-templates](https://github.com/simonvanlierde/project-templates) repository, not in your project.
[Legal pages](usage.md#legal-pages) in the usage guide says how the app builds the pages and
which tests check them.

These are tips for keeping the pages true, not legal advice. When the stakes are real, ask a
lawyer or your organisation's privacy officer.

## Fill in every TODO

Each page starts with what the template knows: the name, the address, your email and today's
date. The rest is marked TODO, and `just ts-e2e` fails until none is left: a page that guesses is
worse than no page. Write only what you can check. When code makes a page untrue, change the page
in the same pull request.

## Who is responsible

- **A personal project:** you are the data controller, the one who decides what happens to the
  data. Your name and email go on the privacy statement.
- **An app run for an organisation** (a university, a company, a public body): the organisation is
  the controller, not you. Name it on the privacy statement, have its privacy officer review the
  text before launch, and link the organisation's own privacy statement from yours.
- **A public-sector site in the EU** falls under the Web Accessibility Directive, (EU) 2016/2102,
  and must publish its country's model accessibility statement, which builds on the EU model in
  [Implementing Decision (EU) 2018/1523](https://eur-lex.europa.eu/eli/dec_impl/2018/1523/oj).
  Its mandatory sections differ from this page:
  - **Compliance status:** "fully compliant", "partially compliant" or "not compliant" with a
    named standard, or with the national law. There is no "not assessed". The standard is
    usually EN 301 549, which the Commission named as the harmonised standard under article 6
    of the Directive
    ([Implementing Decision (EU) 2018/2048](https://eur-lex.europa.eu/eli/dec_impl/2018/2048/oj),
    as amended), and whose web requirements build on WCAG.
  - **Non-accessible content:** split by reason: non-compliance with the national law, a
    "disproportionate burden" exemption (article 5 of the Directive), or content outside the
    law's scope, with accessible alternatives where there are any. This page has one "Known
    problems" list.
  - **Preparation of this accessibility statement:** the date it was prepared, the method
    (an evaluation such as a self-assessment or an assessment by a third party, article 3(1) of
    the Decision) and
    the date of the last review. This page's "About this statement" holds the same facts.
  - **Feedback and contact information:** a feedback mechanism for reporting problems and for
    asking for content the Directive leaves out, and who handles it. "Tell us about a problem"
    covers the first part only.
  - **Enforcement procedure:** a description of, and a link to, where people can turn when
    the reply to their feedback is not good enough, with the enforcement body's contact
    details. This page has no such section.

  In the Netherlands the statement is the one the Bdto (Besluit digitale toegankelijkheid
  overheid) requires, made with the wizard on
  [toegankelijkheidsverklaring.nl](https://www.toegankelijkheidsverklaring.nl/) and listed in its
  register. Link it from "About this statement" and keep this page as the readable
  version.

## Accessibility statement

- Every claim must be checkable in the repository: the tests in `tests/e2e/`, the lint rules in
  `biome.json`, the styles in `src/app.css`. When you fix a known problem, move its bullet from
  "Known problems" to "How we check" in the same pull request as the fix.
- The status says "not assessed" until someone has checked every WCAG 2.2 criterion. That
  check goes in `docs/accessibility-assessment.md`, which the app does not serve: one row for
  each of the 55 level A and AA criteria, with a result and the evidence for it. Say
  "partially conformant" only once every row has a result, link the assessment from the status
  sentence, and name the criteria that fail under "Known problems".
  The statement test refuses "fully conformant": that needs a full external audit, so change the
  test only once you have one.
- Review it at least once a year. The test fails when "Last reviewed" is more than 400 days old.
- Give each known problem a way around it, and a fix date or "No fix planned".

## Privacy statement

- Say what is kept, where, for how long, and who else gets it. IP addresses in server logs can
  count as personal data, so the hosting section stays even for an app that keeps nothing.
- For each kind of data, server logs and accounts alike, give its purpose, its legal basis and
  how long it is kept. Article 13 of the GDPR lists what a privacy statement must tell people,
  among them "the purposes of the processing … as well as the legal basis for the processing"
  (13(1)(c)) and "the period for which the personal data will be stored, or if that is not
  possible, the criteria used to determine that period" (13(2)(a)). Article 6(1) lists the legal
  bases. An account is usually "necessary for the performance of a contract" with the user (b).
  For server logs, recital 49 gives network and information security as an example of a
  legitimate interest (f): processing "strictly necessary and proportionate" for it
  "constitutes a legitimate interest of the data controller concerned". A statement that relies
  on 6(1)(f) must also name the interest it pursues (13(1)(d)), such as keeping the site
  running and safe.
- Change "Last updated" with every edit to the page.
- Keep Cloudflare Web Analytics off for the Pages project. When it is on, "Cloudflare will
  automatically add the JavaScript snippet to your Pages site on the next deployment"
  ([Cloudflare: Enable Web Analytics](https://developers.cloudflare.com/pages/how-to/web-analytics/)),
  and that script must be allowed in the Content-Security-Policy's `script-src`
  ([Web Analytics FAQ](https://developers.cloudflare.com/web-analytics/faq/)). The rendered
  `public/_headers` blocks it, and the privacy statement says the app loads only its own files.
  The e2e tests run against a local build, so they can't see it. For visitor numbers, see
  Analytics below.
- After the first deploy, look in the host's dashboard for other analytics or bot-protection
  features that set cookies or add scripts. Then check that `curl -sI <site_url> | grep -i set-cookie`
  prints nothing.
- Name every outside service the app calls. Loading a font, a script or an image from another site
  sends the visitor's IP address there; a rendered app loads nothing from other sites, and
  `tests/e2e/privacy.spec.ts` fails if a page does.

## Cookies and other storage

- **The rule covers any storage, not only cookies.** Article 11.7a of the Dutch
  Telecommunicatiewet, the Dutch form of article 5(3) of the EU ePrivacy Directive, applies to
  "het … opslaan van of toegang verkrijgen tot informatie in de randapparatuur van een gebruiker":
  storing or reading any information on the user's device. The European Data Protection Board
  reads article 5(3) the same way: storage counts whatever the medium, the technique or how long
  it lasts ([Guidelines 2/2023](https://www.edpb.europa.eu/system/files/2024-10/edpb_guidelines_202302_technical_scope_art_53_eprivacydirective_v2_en_0.pdf),
  paragraphs 35 to 38). So `localStorage`, `sessionStorage` and IndexedDB fall under the same rule
  as cookies. The Board adds (paragraph 44) that an app using information that stays on the device,
  such as local storage, is not "gaining access" to it, but article 5(3) applies once that
  information, or anything derived from it, leaves the device.
- **What needs no consent.** Article 5(3) of the ePrivacy Directive exempts two cases: storage or
  access "for the sole purpose of carrying out the transmission of a communication…", and storage
  or access "strictly necessary in order for the provider of an information society service
  explicitly requested by the subscriber or user to provide the service" (the wording the
  Article 29 Working Party quotes as its criteria A and B in
  [Opinion 04/2012 on the cookie consent exemption](https://ec.europa.eu/justice/article-29/documentation/opinion-recommendation/files/2012/wp194_en.pdf)).
  [Article 11.7a, third paragraph](https://wetten.overheid.nl/jci1.3:c:BWBR0009950&hoofdstuk=11&artikel=11.7a)
  carries both over and adds a third, which is Dutch only: storage or access "om informatie te
  verkrijgen over de kwaliteit of effectiviteit van een geleverde dienst…", to learn about the
  quality or effectiveness of the service, provided it has "geen of geringe gevolgen" (no or
  minor consequences) for the user's privacy. Outside the Netherlands, check your own country's
  law before relying on that third case.
- **Keeping the user's own work is strictly necessary.** The Working Party counts "user-input"
  storage, such as a form filled in over several pages or a shopping cart, as needed for a
  service the user explicitly asked for, and adds that "the user may explicitly ask the service
  to remember some information from one session to another" (Opinion 04/2012, sections 2.3 and
  3.1). So an app that saves the user's work in local storage because they asked it to, and for
  nothing else, needs no banner. Say in the privacy statement what it keeps.
- **Limited analytics, in Dutch practice.** The Autoriteit Persoonsgegevens calls the third case
  "limited analytics cookies", such as counting visitors and the most visited pages: they need no
  consent when their impact on privacy is small, but still need a legal basis if they process
  personal data, and must be listed in the privacy statement
  ([AP: Cookies](https://www.autoriteitpersoonsgegevens.nl/en/themes/internet-and-smart-devices/cookies),
  last edited 6 May 2025). Functional cookies need no consent either, but must be mentioned too.
  The AP pages talk about cookies only; they do not mention local storage.
- **No banner by default.** A rendered app sets no cookies and stores nothing before the user acts,
  and the privacy test proves it on first load. With nothing to consent to, a banner only adds
  noise. The AP notes the same: an organisation that stops collecting personal data no longer needs
  consent and can remove its banner
  ([AP: Cookies and your organisation](https://www.autoriteitpersoonsgegevens.nl/en/themes/internet-and-smart-devices/cookies/cookies-and-your-organisation-make-sure-you-have-a-good-cookie-policy-in-place)).
- **Analytics.** If you want visitor numbers, pick a counter that does not follow visitors across
  sites; the AP names Matomo, Plausible Analytics, Apache Superset and OpenPanel, "provided they are
  configured correctly". Describe it in the privacy statement. Served from the app's own origin, it
  needs no change to the tests or the Content-Security-Policy. On another origin, add that origin to
  `OTHER_ORIGINS` in `tests/e2e/privacy.spec.ts` and to `script-src` and `connect-src` in
  `public/_headers`. Anything that tracks people across sites, such as advertising, needs consent
  first, and refusing must be as easy as accepting.

## Terms of use

Only an app with accounts or uploads needs terms. Keep them short, and match them to the
privacy statement. They say who owns uploaded content, the licence it is
shared under, what users promise, and how to remove it. A free tool with no accounts is covered by
its licence and the no-warranty line at the end of the privacy statement.

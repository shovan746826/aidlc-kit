# Question Bank

Use this to find **what to ask**, never to ask everything. First read the code, the profile and earlier
documents; then ask only what is still unknown **and** changes what gets built.
Turn each question into the multiple-choice format of `00-aidlc-core.md` §4: options, one ★ recommendation
with its reason, and "why it matters". At most 10 questions per round.

## A. Business and vision
- A1. In one sentence: what is the product and who is it for?
- A2. Which problem does it solve? How do people solve it today?
- A3. Why will users choose it over the alternatives? (price · simplicity · a key feature · local market · …)
- A4. Known competitors or similar apps? What do you like or dislike about them?
- A5. Business model: free · freemium · subscription · one-time purchase · ads · in-app purchases · B2B · not decided
- A6. Pricing ideas and the boundary between free and paid.
- A7. Monthly budget limit for services (backend, maps, SMS, AI, analytics)?
- A8. Deadline or launch date? Fixed milestones (demo, investor meeting, season)?
- A9. Success after 6 months: which numbers? (downloads · active users · paying users · revenue · rating)
- A10. Team: who builds the backend, the design, the tests, and who publishes to the stores?

## B. Users and journeys
- B1. Main user types (personas) and what each one wants to get done.
- B2. The 3 most important journeys, step by step.
- B3. Countries, languages (right-to-left?), currencies, time zones.
- B4. Accessibility needs (screen readers, large text, color contrast).
- B5. Admins or operators: what do they need (dashboard, moderation, support tools)?

## C. Scope and features
- C1. MVP features: must · should · could · won't (for now).
- C2. What is explicitly out of scope?
- C3. Accounts: none · guest + optional login · login required.
- C4. Content: who creates it, how much, how is it updated?
- C5. Notifications: which events · push · in-app · email · SMS?
- C6. Settings and personalization.
- C7. Offline: must the main flows work without internet?

## D. Platforms and devices
- D1. Platforms: Android · iOS · web · desktop.
- D2. Minimum versions (Android API level, iOS version).
- D3. Phones only, or tablets and foldables too? Orientation?
- D4. Dark mode? Dynamic colors?
- D5. Design source: Figma link · screenshots · none (use the design system).

## E. Technical
- E1. Confirm the architecture standard. Any deviations wanted?
- E2. Local storage: what data, how much, how long?
- E3. Offline strategy: online only · cache for reading · offline-first with sync.
- E4. Performance targets (startup time, list sizes, image-heavy screens).
- E5. Environments / flavors (dev · staging · prod) and how they differ.
- E6. Code generation allowed (freezed, json_serializable, riverpod_generator, Hilt, …)?
- E7. Navigation structure (bottom tabs · drawer · single stack) and deep links.

## F. Integration
- F1. Backend: exists · being built (by whom?) · needed (custom API · Firebase · Supabase · other).
- F2. API documentation (Swagger / Postman link)? Base URLs per environment?
- F3. Authentication: email + password · phone OTP · Google · Apple · Facebook · SSO · none. Token type and refresh?
- F4. Payments: store in-app purchases · subscriptions · payment gateway (which?) · none.
- F5. Push notifications: Firebase Cloud Messaging · other · none. Topics or per user?
- F6. Analytics and crash reporting: Firebase Analytics / Crashlytics · Sentry · other.
- F7. Maps and location: provider; foreground or background location?
- F8. Files and media: size limits, storage (S3 · Firebase Storage · own server), compression.
- F9. Email / SMS / WhatsApp providers.
- F10. Other SDKs (chat, video, AI, ads) and who owns their accounts.
- F11. Rate limits, quotas, cost per call we must respect?
- F12. Who owns each third-party account and key? Where are secrets kept (CI secrets, env files)?

## G. Data and privacy
- G1. Personal data collected (name · phone · email · location · contacts · photos · financial · health).
- G2. Laws and policies that apply (GDPR · local data-protection law · children's privacy · store policies).
- G3. Consent, data export and account-deletion requirements.
- G4. Data retention and backups.
- G5. Encryption needs (at rest, in transit, sensitive fields).

## H. Quality
- H1. Test expectations (unit · widget/UI · integration · manual QA on devices).
- H2. Devices to test on.
- H3. Accessibility target.
- H4. Languages at launch; who translates?
- H5. Error experience (messages, retry, support contact).

## I. Release and operations
- I1. Store accounts ready (Google Play Console, Apple Developer)? Who publishes?
- I2. App name, package / bundle id, icon, splash, store-listing languages.
- I3. CI/CD: none · GitHub Actions · Codemagic · Bitrise · other.
- I4. Versioning and release cadence.
- I5. Rollout: internal → closed → production; staged percentage?
- I6. Who watches crashes and reviews after release?
- I7. Support channel and privacy-policy URL.

## J. Feature-specific (existing project)
- J1. Goal: what should the user be able to do that they cannot do today?
- J2. Entry point: which screen or button starts it? Where does the user go after success or cancel?
- J3. Screens and states: loading · empty · error · success · offline.
- J4. Data: which API endpoints (method, URL, request and response JSON)? New or existing? Who provides them?
- J5. Business rules and validation (limits, formats, rules per user type).
- J6. Edge cases (no network, slow network, empty data, very long text, duplicates, time zones).
- J7. Platform permissions or settings (camera, location, notifications, contacts).
- J8. Analytics events to send.
- J9. Feature flag or remote config?
- J10. Acceptance: how will you check that it works (devices, accounts, test data)?

## K. Bug triage
- K1. Steps to reproduce (exact taps and inputs).
- K2. Expected result vs actual result.
- K3. How often (always · sometimes · once)? Since when (version, date, recent change)?
- K4. Device, OS version, app version and build, account type.
- K5. Logs, error messages, screenshots, screen recordings.
- K6. Severity (crash or data loss · blocks a main flow · has a workaround · cosmetic) and who is affected.
- K7. Is there a workaround?

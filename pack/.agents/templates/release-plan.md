# Release Plan: <version>

> Status: DRAFT | APPROVED <date-time> | COMPLETED <date-time>
> Platforms: Android · iOS · … · Tracks: internal · closed · open · production · TestFlight · App Store · Target date: …
> 🛑 The agent never publishes, uploads, tags or pushes by itself. The user does it, or approves each action.

## 1. What's in this release
| Work item | Title | Type |
|---|---|---|

## 2. Version
- Current: `x.y.z+build` → New: `x.y.z+build` · Reason (patch · minor · major): …

## 3. Changelog
- **For users (store "What's new"):** …
- **Internal:** …

## 4. Pre-release checklist
- [ ] Production config: API base URLs, flavors, feature flags, remote config
- [ ] Secrets come from CI or env files, not code
- [ ] Analytics and crash reporting enabled for release builds
- [ ] New permissions have usage texts (Info.plist, AndroidManifest.xml)
- [ ] Privacy labels / data-safety form updated for new data or SDKs
- [ ] Store listing: screenshots, description, what's new
- [ ] Signing ready (keystore, certificates, profiles) without committing secrets
- [ ] Obfuscation and debug symbols (if used) are uploaded to crash reporting

<!-- aidlc:files:begin · only files listed in the two tables below may be changed after approval. Only the Path column counts: one or more full paths in backticks per row. Backticks in other columns never add files. -->
## 5. Files to modify
| # | Path | What changes |
|---|---|---|
| M1 | `pubspec.yaml` | `version:` → new version |
| M2 | `CHANGELOG.md` | add release notes |

## 6. Files to create
| # | Path | Purpose |
|---|---|---|
<!-- aidlc:files:end -->

## 7. Build commands (only these will be run)
| Platform | Command | Artifact |
|---|---|---|
| Android | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS | `flutter build ipa --release` | `build/ios/ipa/*.ipa` |

## 8. Rollout and rollback
- Rollout: track and staged percentage, timing
- Rollback: halt the staged rollout; hotfix process; server-side flags

## 9. Monitoring after release
| Metric | Target | Where to watch | Who |
|---|---|---|---|
| Crash-free users | | | |
| ANRs / hangs | | | |
| Ratings and reviews | | | |
| Key KPIs | | | |

## 10. Task plan
### Phase 1: Prepare
- [ ] ⏳ **[PENDING]** Update the version and the changelog
- [ ] ⏳ **[PENDING]** Complete the pre-release checklist
### Phase 2: Build
- [ ] ⏳ **[PENDING]** Run the approved build commands and record artifacts and sizes
### Phase 3: Verify
- [ ] ⏳ **[PENDING]** Smoke-test checklist on a real device (user)
### Phase 4: Hand-over
- [ ] ⏳ **[PENDING]** Give the user the exact publishing steps (the user publishes)
### Phase 5: After release
- [ ] ⏳ **[PENDING]** Monitoring check, lessons learned, feature registry updated

## 11. Plan changes (after approval)
| ID | Date-time | File and change | Reason | Status |
|---|---|---|---|---|

---
**Ready to approve?** ☐ every included work item is completed ☐ version and changelog are right ☐ checklist
reviewed ☐ build commands listed ☐ rollback defined ☐ the example rows match this project

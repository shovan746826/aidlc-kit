---
id: S-028
title: Confirm a new package's exact name on the official registry before adding it
type: pitfall
scope: shared
stack: any
tags: [packages, security, hallucination]
status: active
confidence: high
source: research
evidence: Spracklen et al. 2024 https://arxiv.org/abs/2406.10279 · 16 code models · 19.7% of suggested packages did not exist (5.2% for commercial models) · attackers register such names (slopsquatting)
created: 2026-10-23
last_verified: 2026-10-23
recheck: 2027-04-23
helpful: 0
harmful: 0
shared_as: S-028
---

# Confirm a new package's exact name on the official registry before adding it

**When it applies:** A plan or a fix adds a dependency (pub.dev, Maven Central, CocoaPods / Swift Package
Index, npm, PyPI).

**Do:** Open the package's page on the official registry and check the exact name, the publisher, recent
releases and the version you will use. Put the URL in the plan's Facts and assumptions table, then add the
package with the stack's own command (for example `flutter pub add <name>`).

**Don't:** Don't add a package name from memory or from a code sample without checking that it exists and is
the one you mean.

**Why:** Code models suggest packages that do not exist, and attackers publish packages under such names
("slopsquatting"), so a guessed name can install malicious code.

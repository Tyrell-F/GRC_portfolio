# Project 1: Locked-Down Azure VM (vm-grc-01)

A hardened Ubuntu server in Microsoft Azure, built, assessed against NIST SP 800-53 Rev. 5, and documented the way a GRC analyst would package a system for authorization: a mini SSP, a POA&M with risk register, a remote access policy, and an evidence binder.

**Author:** Tyrell Freeman | **Built:** November 7 to 10, 2026 | **Categorization:** FIPS 199 Low

## What I built

| Layer | Design choice | Controls |
|---|---|---|
| Network | Private subnet, NSG with deny-all inbound, no public IP on the VM | SC-7, AC-17 |
| Remote access | Azure Bastion only (deployed per session, deleted after), SSH keys, passwords and root login disabled | AC-17(3), IA-5, AC-6 |
| Compute | Ubuntu 24.04, Trusted launch (Secure Boot, vTPM) | SI-7, CM-2 |
| Data at rest | OS disk encrypted with a platform-managed key | SC-28 |
| Patching | NAT gateway egress for updates, fully patched, periodic patch assessment | SI-2 |
| Cost and governance | $20 budget with 50/80/100% alerts, auto-shutdown at 7 PM, tagging | PM-3, CM-8 |
| Continuous monitoring | Azure Policy NIST SP 800-53 Rev. 5 initiative assigned to the resource group | CA-2, CA-7, RA-5 |

## Key finding

After the first patch run, `apt` reported the system "up to date" while every repository fetch was silently timing out. The subnet was private and the NAT gateway had no outbound public IP, so the VM had no path to update servers. A patching control that looked compliant was not working. I traced the root cause, added the public IP, and verified with `apt list --upgradable` returning nothing (evidence E07a, B13, E07b, E07c).

## Assessment results

| | Policies non-compliant | Controls non-compliant |
|---|---|---|
| Baseline scan | 22 of 694 | 24 of 970 |
| After remediation | 19 of 693 | 19 of 970 |

I triaged the 22 failing policies as follows: 12 were evaluation gaps (no guest agent or Defender data), 6 were real configuration gaps, 3 were risk-accepted (backup, disaster recovery, DDoS protection), and 1 did not apply (SQL). The real gaps became POA&M items. Four are closed (root login, unused Bastion subnet, IP forwarding verification, budget alert recipient), and the rest are tracked with owners and dates. Several are planned for Project 2 (Key Vault and customer-managed keys).

## Files

| File | What it is |
|---|---|
| [vm-grc-01_Mini_SSP.pdf](vm-grc-01_Mini_SSP.pdf) | System Security Plan: system identification, boundary and architecture, control implementation, assessment results |
| [vm-grc-01_POAM_Risk_Register.xlsx](vm-grc-01_POAM_Risk_Register.xlsx) | POA&M (11 items), risk register (NIST SP 800-30 style scoring), policy triage, and risk acceptances |
| [vm-grc-01_Remote_Access_Policy.pdf](vm-grc-01_Remote_Access_Policy.pdf) | Remote access policy for the system (AC-17) |
| [vm-grc-01_Evidence_Binder.pdf](vm-grc-01_Evidence_Binder.pdf) | 46-page evidence binder with an index mapping every screenshot to its controls |
| [evidence/](evidence/) | Individual screenshots (B = build, E = evidence, F = fix) |
| [data/](data/) | Azure Policy compliance exports (controls, failing policies before and after) |

## Tools and skills

Azure Portal, Azure Bastion, NSGs, NAT gateway, Network Watcher IP flow verify, Azure Policy and regulatory compliance, VM Run command, Cloud Shell (Azure CLI), Cost Management budgets. Frameworks: NIST SP 800-53 Rev. 5, FIPS 199, NIST SP 800-30.

## Notes

- Subscription IDs, billing IDs, email addresses, and phone numbers are redacted from all screenshots.
- The compliance initiative is Microsoft's built-in NIST SP 800-53 Rev. 5 definition. I assigned it, ran the scans, and analyzed the results. The triage and POA&M are my own work.
- The lab was torn down to a minimal footprint between sessions to stay within budget.

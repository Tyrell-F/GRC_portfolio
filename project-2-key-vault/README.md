# Project 2: Key Vault, Customer-Managed Keys, and Managed Identity (vm-grc-01)

Project 2 extends the [Project 1](../project-1-locked-down-vm/) server with Azure Key Vault, customer-managed disk encryption, a managed identity with least-privilege secret access, central logging, and integrity monitoring. I then re-assessed the system against NIST SP 800-53 Rev. 5 and updated the SSP, POA&M, and risk register.

**Author:** Tyrell Freeman | **Built:** November 18 to 20, 2026 | **Categorization:** FIPS 199 Low

## What I built

| Layer | Design choice | Controls |
|---|---|---|
| Key management | Key Vault with RBAC, purge protection, and soft delete; RSA 3072 key with a 12-month expiry and auto-rotation at 11 months | SC-12, SC-13 |
| Data at rest | OS disk encrypted with the customer-managed key through a disk encryption set; encryption at host for cache and temp disks | SC-28, SC-28(1) |
| Workload identity | VM system-assigned managed identity; Key Vault Secrets User scoped to a single secret, so no credentials are stored on the VM | AC-3, AC-6, IA-5 |
| Logging | Log Analytics workspace (0.1 GB/day cap) receiving Key Vault audit logs and the Activity Log; saved KQL queries for review | AU-2, AU-6, AU-12 |
| Integrity | Trusted launch integrity monitoring with the guest attestation extension | SI-7 |
| Host hardening | Lynis host audit (hardening index 62) and unattended security upgrades | RA-5, SI-2 |
| Governance | Key Management Standard written for the system | SC-12, PL-2 |

## Key findings

**Least privilege, verified rather than assumed.** Before any role was granted, the VM's managed identity got HTTP 403 from Key Vault. After I scoped Key Vault Secrets User to one secret, the same token returned 200 for that secret and 403 for another, and both results appear in the Key Vault audit log (K10, K15b, K16b).

**The control works, but the configuration record disagrees.** The OS disk passes the customer-managed key policy, and KeyUnwrap events prove the key is in use (K16). The VM resource still fails the same policy because its configuration does not reference the disk encryption set (K23, K23b). The data is protected, but any tool that reads the VM's configuration would report it as not using a customer-managed key. I tracked it as a configuration management finding (POAM-15) instead of treating the policy result as the full story.

**Not every failing policy is a real gap.** The subnet NSG policy kept failing after Project 1. I traced it to snet-vm1 and confirmed nsg-vm is attached (K24, K25). The policy reads a Defender for Cloud assessment that does not exist without Defender for Servers, so I classified it as an evaluation gap with direct evidence.

## Assessment results

| Scan | Policies non-compliant | Controls non-compliant |
|---|---|---|
| Project 1 baseline (2026-11-09) | 22 of 694 | 24 of 970 |
| After Project 1 fixes (2026-11-10) | 19 of 693 | 19 of 970 |
| After Project 2 (2026-11-19) | 22 of 693 | 17 of 970 |

Failing controls dropped from 19 to 17. The policy count rose because adding a vault and a workspace brought four new checks: the vault's public network access and private link (POA&M), double encryption, and saved queries in customer storage (both risk-accepted with written justification). Encryption at host moved to compliant.

Of the 22 failing policies, 12 are evaluation gaps, 4 are real gaps, 5 are risk-accepted, and 1 does not apply. The POA&M now has 16 items, 7 of them closed. Project 2 closed POAM-03 (customer-managed keys), POAM-08 (central logging), and POAM-11 (integrity monitoring), and added items for the vault's public endpoint, a host firewall, inherited university admin access, the VM configuration record, and alert rules.

## Files

| File | What it is |
|---|---|
| [vm-grc-01_SSP_v2.pdf](vm-grc-01_SSP_v2.pdf) | System Security Plan v2: updated boundary diagram, 27 controls, assessment results, evidence index |
| [vm-grc-01_Key_Management_Standard.pdf](vm-grc-01_Key_Management_Standard.pdf) | Cryptographic Key Management Standard (SC-12): roles, key requirements, lifecycle, logging, exceptions |
| [vm-grc-01_POAM_Risk_Register_v2.xlsx](vm-grc-01_POAM_Risk_Register_v2.xlsx) | POA&M (16 items), risk register (13 risks), policy triage, and risk acceptances |
| [evidence/](evidence/) | Screenshots (K = evidence, KB = build and troubleshooting) |
| [data/](data/) | Azure Policy export of failing policies after Project 2 |

## Tools and skills

Azure Key Vault (RBAC), disk encryption sets, encryption at host, managed identities and the instance metadata service, Log Analytics and KQL, diagnostic settings, Trusted launch and guest attestation, Azure Policy, Cloud Shell (Azure CLI), VM Run command, Lynis. Frameworks: NIST SP 800-53 Rev. 5, FIPS 199, NIST SP 800-30.

## Notes

- Subscription, tenant, and object IDs, email addresses, and the Caller column are redacted from all screenshots.
- The test secret holds a placeholder value. No real credential was stored or shown.
- The compliance initiative is Microsoft's built-in NIST SP 800-53 Rev. 5 definition, and Lynis is an open-source tool. I ran and analyzed both. The triage, POA&M, SSP, and Key Management Standard are my own work.
- The NAT gateway and Bastion are deployed only for admin sessions and deleted afterward to stay within budget.

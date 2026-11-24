# Project 3: Infrastructure as Code with a Security Gate (vm-grc-01)

Project 3 rebuilds the [Project 1](../project-1-locked-down-vm/) and [Project 2](../project-2-key-vault/) system entirely in Terraform, behind a GitHub Actions pipeline that runs Checkov on every pull request and blocks insecure changes from reaching main. The rebuild closed five POA&M items, retired one risk acceptance, and cut non-compliant NIST controls from 17 to 12. I then wrote a Configuration Management Plan and updated the SSP and POA&M.

**Author:** Tyrell Freeman | **Built:** November 21 to 24, 2026 | **Categorization:** FIPS 199 Low

## What I built

| Layer | Design choice | Controls |
|---|---|---|
| Infrastructure as code | 38 Terraform-managed resources in 10 files (azurerm 4.81, azapi 2.14); one resource group in West US 2 | CM-2, CM-8 |
| Change gate | GitHub Actions: `terraform fmt` + `validate` and a Checkov scan, both required on a protected main branch; results in Code scanning | CM-3, CM-3(2), SA-11 |
| Key Vault network | Public access disabled; private endpoint and private DNS zone; key and disk encryption set created through the ARM API so they work with the public endpoint off | SC-7, AC-4, SC-12 |
| Data at rest | Double encryption (platform + customer-managed key), declared on the VM so the configuration record matches the disk | SC-28, SC-28(1) |
| Host baseline | cloud-init applies ufw (SSH from the VNet only), SSH hardening, unattended upgrades and Lynis on every build | CM-6, SC-7, SI-2 |
| Detection | Two log alert rules email the owner: denied secret reads and role assignment changes (classic and PIM) | AU-6, SI-4, AC-2(4) |
| Cost and drift | NAT gateway and Bastion are code switches, off by default; `terraform plan` detects portal changes | PM-3, CM-3 |
| Governance | Configuration Management Plan (CM-9) | CM-9, CM-4 |

The Terraform code and pipeline are in [terraform/](terraform/) and [.github/workflows/](../.github/workflows/).

## Key findings

**The gate works.** A test pull request that opened SSH to the internet and turned the vault's public access back on failed Checkov (CKV_AZURE_10, CKV_AZURE_189) and could not be merged. It was closed without ever reaching main or Azure (T04 to T06).

**The network layer stops even an authorized admin.** I hold Key Vault Administrator, yet reading a secret from Cloud Shell was refused with ForbiddenByConnection. From inside the VNet, the VM's identity reached the vault at its private IP and got 200 on its one secret and 403 on the others (T12, T13).

**Testing found a detection gap the deployment hid.** The role-change alert deployed cleanly and never fired. The university tenant uses Privileged Identity Management, so a role added in the portal is logged as a PIM eligibility request, not a classic role assignment. I widened the query in a pull request, applied it, and a repeat test fired the alert in about five minutes (TB39 to TB43, T17b).

**Locking down the network broke my own tooling, and the fix had to stay locked down.** With the vault's public endpoint off, Terraform's standard disk encryption resource could not read the key. Rather than reopen the vault, I created the key and the disk encryption set through the ARM API, which stays inside Azure (TB15, PR #3).

**Drift is now visible.** I changed a tag in the portal; `terraform plan` reported exactly that change and `terraform apply` put it back (T18).

## Assessment results

| Scan | Scope | Policies non-compliant | Controls non-compliant |
|---|---|---|---|
| Project 1 baseline (2026-11-09) | rg-grc-lab | 22 of 694 | 24 of 970 |
| After Project 2 (2026-11-19) | rg-grc-lab | 22 of 693 | 17 of 970 |
| After Project 3 (2026-11-23) | rg-grc-tf | 14 of 693 | 12 of 970 |

Of the 14 failing policies, 7 are evaluation gaps (Defender for Servers checks, each contradicted by direct evidence), 2 are real gaps, 4 are risk-accepted, and 1 does not apply. Now passing: Key Vault firewall and private link, the VM-level customer-managed key policy, and double encryption.

Project 3 closed POAM-10, 12, 13, 15 and 16, plus POAM-20 (the PIM gap found in testing), and retired RA-04. Building the pipeline surfaced four new items: actions not pinned to commit SHAs, local Terraform state, the admin bypass on main (risk-accepted), and an uncommitted provider lock file. The POA&M now has 21 items: 13 closed, 7 open, 1 risk-accepted. The old manually built resource group was deleted after the rebuild was verified.

## Files

| File | What it is |
|---|---|
| [vm-grc-01_SSP_v3.pdf](vm-grc-01_SSP_v3.pdf) | System Security Plan v3: architecture diagram, 30 controls, assessment results, evidence index |
| [vm-grc-01_Configuration_Management_Plan.pdf](vm-grc-01_Configuration_Management_Plan.pdf) | Configuration Management Plan (CM-9): baseline, change flow, operating procedures, exceptions, lessons learned |
| [vm-grc-01_POAM_Risk_Register_v3.xlsx](vm-grc-01_POAM_Risk_Register_v3.xlsx) | POA&M (21 items), risk register (15 risks), policy triage, and risk acceptances |
| [terraform/](terraform/) | The Terraform code |
| [evidence/](evidence/) | Screenshots (T = evidence, TB = build and troubleshooting) |
| [data/](data/) | Azure Policy export of failing policies after Project 3 |

## Tools and skills

Terraform (azurerm, azapi), GitHub Actions, Checkov, GitHub Code scanning (SARIF), repository rulesets, Azure Key Vault private endpoints and private DNS, disk encryption sets, cloud-init, Log Analytics and KQL, Azure Monitor alert rules and action groups, Privileged Identity Management, Azure Policy, Cloud Shell (Azure CLI). Frameworks: NIST SP 800-53 Rev. 5, FIPS 199, NIST SP 800-30.

## Notes

- Subscription, tenant and object IDs, email addresses and third-party administrator names are redacted from all screenshots.
- `terraform.tfvars` and Terraform state are git-ignored and never published. The test secret holds a placeholder value.
- Checkov and the NIST initiative are third-party and Microsoft tools. I wrote the Terraform, ran and analyzed the scans, and wrote the triage, POA&M, SSP and Configuration Management Plan.
- The VM is deallocated and the NAT gateway and Bastion are off between sessions to stay within budget.

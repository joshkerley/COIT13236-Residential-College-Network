# Firewall and Access Control Policy Matrix

**Project:** Regional Uni Colleges, Secure High-Density Residential College Network
**Unit:** COIT13236 Cyber Security Project, Term 2 2026
**Author:** Anshul Bairy (Onboarding and Access Control Lead)
**Date:** 16 August 2026
**Status:** Draft 01, for group review

---

## 1. Purpose

The network design defines ten VLANs and a complete addressing plan, but it does not yet
state which VLAN is permitted to reach which. This document supplies that policy. It is the
control layer that the isolation and abuse-response demonstrations are actually tested
against, so it needs to be agreed before pfSense rules are written.

The policy is expressed twice. Section 4 is a plain allow and deny matrix for the report and
for group agreement. Section 5 breaks each VLAN into the specific rules that will be entered
into pfSense, including ports, so the configuration can be built directly from this document.

## 2. Design principle: default deny

Every VLAN interface starts with an implicit deny at the bottom of its rule set. Nothing is
permitted unless it appears explicitly in this policy. Rules are ordered most specific first,
with the broad internet allow last, so a narrow deny is never shadowed by a wide allow.

This is chosen over the alternative of allowing everything and blocking known problems. On a
BYOD network the set of things residents might attempt is not knowable in advance, so an
allow list is the only defensible position. It is also easier to justify to the client and
easier to test, because every permitted path is written down and can be verified one at a
time.

## 3. Where each control is enforced:

This distinction matters and is easy to get wrong.

| Control | Enforced on | Why |
|---|---|---|
| Between different VLANs | pfSense | Traffic crosses the gateway, so the firewall sees it |
| Between devices in the same VLAN | Open vSwitch port isolation | Traffic is switched at layer 2 and never reaches pfSense, so firewall rules cannot see it |
| Which VLAN a device lands in | PacketFence (RADIUS) | Assignment happens at authentication time, before any traffic is routed |
| Moving a device to quarantine | PacketFence, then pfSense | PacketFence issues the reassignment, pfSense enforces the restricted policy |

**Consequence for the build:** resident-to-resident isolation is not a firewall task. Writing
a pfSense rule that denies 10.50.10.0/23 to 10.50.10.0/23 does nothing, because two residents
on VLAN 10 talk directly through the switch. It has to be port isolation on Open vSwitch.
This is the single most important line in this document.

## 4. Policy matrix

Read as: row is the source, column is the destination.

Key: **A** allow, **D** deny, **L** limited (specific hosts or ports only, see Section 5)

| From \ To | Res A (10) | Res B (11) | Res C (12) | Guest (20) | Staff (30) | IoT (40) | Mgmt (50) | NAC/SSO (60) | Mon (70) | Quar (80) | Uni Services | Internet |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Resident A (10)** | D (OVS) | D | D | D | D | D | D | L | D | D | D | A |
| **Resident B (11)** | D | D (OVS) | D | D | D | D | D | L | D | D | D | A |
| **Resident C (12)** | D | D | D (OVS) | D | D | D | D | L | D | D | D | A |
| **Guest (20)** | D | D | D | D (OVS) | D | D | D | L | D | D | D | A |
| **Staff (30)** | D | D | D | D | A | D | D | L | D | D | A | A |
| **IoT (40)** | D | D | D | D | D | D | D | D | D | D | D | L |
| **Management (50)** | A | A | A | A | A | A | A | A | A | A | A | A |
| **NAC / SSO (60)** | L | L | L | L | L | L | D | A | L | L | D | L |
| **Monitoring (70)** | D | D | D | D | D | D | D | D | A | D | D | L |
| **Quarantine (80)** | D | D | D | D | D | D | D | L | D | D (OVS) | D | D |

### Notes on the matrix

- **Residents to NAC/SSO is limited, not open.** Residents need the PacketFence portal and
  Keycloak to authenticate, and nothing else on VLAN 60. Opening the whole server VLAN to
  hundreds of BYOD devices would undo the point of segmenting it.
- **Guests are internet only.** No internal destination at all beyond the portal. This is the
  simplest demonstration of isolation in the whole build and should be tested first.
- **IoT egress is limited, not open.** College-owned IoT devices have no legitimate reason to
  reach arbitrary internet hosts. Restricting egress contains a compromised device rather
  than letting it call home freely.
- **Management is the only source with broad allow.** Inbound to Management from anywhere
  else is denied without exception. This is the administrative boundary and it should be the
  most tightly held rule in the policy.
- **Monitoring does not initiate traffic to clients.** Logs and flows are pushed to it, it
  does not reach out. This keeps the monitoring VLAN passive and reduces its value as a
  pivot point if it were ever compromised.
- **Quarantine reaches the remediation page and nothing else.** Not even the internet. A
  quarantined device is there because it is suspected of abuse, so general egress defeats
  the purpose.

## 5. Rule detail by VLAN

Ports are listed so these can be entered into pfSense directly.

### Resident VLANs 10, 11, 12

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | This VLAN gateway | UDP 67, 68 | DHCP |
| 2 | Allow | This VLAN gateway | UDP/TCP 53 | DNS |
| 3 | Allow | PacketFence 10.50.60.10 | TCP 80, 443, 8080, 8443 | Registration and captive portal |
| 4 | Allow | Keycloak 10.50.60.20 | TCP 443 | SSO authentication |
| 5 | Deny | 10.50.0.0/16 | any | All other internal traffic |
| 6 | Allow | any | any | Internet |

Rule 5 before rule 6 is what makes this work. Without it, the internet allow would also
permit every internal destination.

Same-VLAN isolation is handled on Open vSwitch and does not appear in this table.

### Guest VLAN 20

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | This VLAN gateway | UDP 67, 68 | DHCP |
| 2 | Allow | This VLAN gateway | UDP/TCP 53 | DNS |
| 3 | Allow | PacketFence 10.50.60.10 | TCP 80, 443, 8080, 8443 | Guest portal |
| 4 | Deny | 10.50.0.0/16 | any | All internal traffic |
| 5 | Allow | any | any | Internet |

Bandwidth limiting on this VLAN is a declared stretch goal and is not part of this policy.

### Staff VLAN 30

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | This VLAN gateway | UDP 67, 68, 53 | DHCP and DNS |
| 2 | Allow | Keycloak 10.50.60.20 | TCP 443 | SSO |
| 3 | Allow | University Services | defined per service | Staff business systems |
| 4 | Deny | 10.50.10.0/23, 10.50.12.0/23, 10.50.14.0/23 | any | Staff do not need resident devices |
| 5 | Deny | 10.50.50.0/24, 10.50.70.0/24 | any | Management and monitoring |
| 6 | Allow | any | any | Internet |

### IoT VLAN 40

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | This VLAN gateway | UDP 67, 68, 53 | DHCP and DNS |
| 2 | Deny | 10.50.0.0/16 | any | No internal access whatsoever |
| 3 | Allow | any | TCP 443, UDP 123 | Vendor services and time sync only |
| 4 | Deny | any | any | Everything else |

### Management VLAN 50

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | any | any | Administrative access to all segments |

Inbound: deny from all VLANs. No exceptions.

### NAC and SSO VLAN 60

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | pfSense and OVS switch | UDP 1812, 1813 | RADIUS authentication and accounting |
| 2 | Allow | pfSense and OVS switch | UDP 3799 | RADIUS Change of Authorization |
| 3 | Allow | Monitoring 10.50.70.10 | UDP 514, TCP 1514 | Send auth events to Wazuh |
| 4 | Allow | any | TCP 443 | Package and vendor updates |
| 5 | Deny | any | any | Everything else |

Rule 2 is the one that makes dynamic reassignment possible. Change of Authorization is how
PacketFence tells the switch to move an already-connected device into a different VLAN
without the user reconnecting. Quarantine automation depends on it, so if CoA is not
permitted, a compromised device stays where it is until it disconnects.

### Monitoring VLAN 70

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | any | TCP 443 | Threat intelligence and rule updates |
| 2 | Deny | 10.50.0.0/16 | any | Monitoring never initiates to clients |
| 3 | Deny | any | any | Default |

Inbound: allow UDP 514 syslog, UDP 2055 netflow and TCP 1514/1515 Wazuh agent from pfSense,
Open vSwitch and PacketFence only.

### Quarantine VLAN 80

| # | Action | Destination | Protocol / Port | Reason |
|---|---|---|---|---|
| 1 | Allow | This VLAN gateway | UDP 67, 68, 53 | DHCP and DNS |
| 2 | Allow | PacketFence 10.50.60.10 | TCP 80, 443 | Remediation page only |
| 3 | Deny | any | any | No internal access, no internet |

## 6. Acceptance tests

Each test maps to a demo moment from the ED-1 brief. These are written before the build so
the component is measured against a stated standard rather than judged afterwards.

| ID | Test | Expected | Demo moment |
|---|---|---|---|
| T1 | Resident A pings its own gateway 10.50.10.1 | Success | 1 |
| T2 | Resident A pings Resident B, both on VLAN 10 | Blocked | 1 |
| T3 | Resident A reaches the internet | Success | 1 |
| T4 | Resident A pings a host on VLAN 11 | Blocked | 1 |
| T5 | Resident A reaches Staff VLAN 30 | Blocked | 1 |
| T6 | Guest reaches the internet | Success | 1 |
| T7 | Guest pings any resident or internal server | Blocked | 1 |
| T8 | Unregistered device connects | Lands on portal, no internal or internet access | 2 |
| T9 | Device authenticates as resident | Assigned to VLAN 10, gets 10.50.10.x | 2 |
| T10 | Same device reconnects later | Assigned automatically, no re-registration | 2 |
| T11 | Device authenticates as staff | Assigned to VLAN 30, not VLAN 10 | 2 |
| T12 | Monitoring flags a resident device | Alert raised in Wazuh | 3 |
| T13 | PacketFence issues CoA on that device | Device moves to VLAN 80 without reconnecting | 3 |
| T14 | Quarantined device attempts internal or internet access | Blocked, remediation page only | 3 |
| T15 | Device cleared and released | Returns to VLAN 10 with normal access | 3 |

T2 is the test the current design would fail without Open vSwitch port isolation, and T13 is
the test that fails if RADIUS CoA is not permitted through the firewall. Those are the two
highest-risk items in the policy.

## 7. Open questions for the group rather than going on based of assumptions

1. What concretely represents University Services? There is no VLAN for it, and without a
   target there is nothing to demonstrate residents being blocked from, which is an MVP
   isolation requirement.
2. Do resident-owned smart TVs sit in IoT VLAN 40 or the resident VLAN? If they sit in 40,
   the same-owner casting feature promised in the proposal crosses VLANs and contradicts
   this policy.
3. Is IoT VLAN 40 for college-owned devices only, or resident-owned as well? This policy
   assumes college-owned.
4. Does the group accept Quarantine having no internet access at all, or is a limited path
   for antivirus updates preferred?

## 8. Next steps

- Group review and agreement on the matrix in Section 4
- Verify Open vSwitch port isolation is achievable in our build, likely via OpenFlow rules
- Enter Section 5 into pfSense once the final VLAN interfaces are configured
- Execute T1 to T7 as soon as the resident and guest test clients exist

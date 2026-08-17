# NAC and Onboarding Component: Design Specification

**Project:** Regional Uni Colleges, Secure High-Density Residential College Network
**Unit:** COIT13236 Cyber Security Project, Term 2 2026
**Author:** Anshul Bairy (Onboarding and Access Control Lead)
**Date:** 16 August 2026
**Status:** Draft 1, for group review
**Covers:** VLAN 60, PacketFence, Keycloak, device registration, dynamic VLAN assignment

---

## 1. Scope of this component

This specification covers the onboarding and access control layer: how a device that has
never been on the network before gets from plugged in to correctly placed, and how the
network later moves that device if it misbehaves.

It maps to Network Access Control and onboarding in the ED-1 MVP, and to demo moment 2, a
new device joins, lands on the right VLAN and gets online. It also supplies the enforcement
half of demo moment 3, because quarantine is an access control decision.

Out of scope here: the monitoring and detection that decides a device is compromised, which
is Thevindu's component. This document defines the interface between the two.

## 2. Platform selection

| Function | Product | Rationale |
|---|---|---|
| NAC, RADIUS, portal, VLAN enforcement | PacketFence | Free, open source, runs on a Linux VM. Handles captive portal registration, 802.1X, dynamic VLAN assignment and device isolation in one package rather than assembling them |
| Identity provider, SSO | Keycloak | Free, self-hosted, supports OpenID Connect, OAuth 2.0 and SAML. Gives a real directory to authenticate against rather than a flat local user list |

Both were proposed by Josh and I agree with the selection. The alternative was FreeRADIUS,
which is lighter and would have been easier to stand up, but it only provides the RADIUS
piece. Registration, the portal and quarantine handling would then all have to be built
separately, which is more total work and more places to fail. PacketFence carries a heavier
install cost in exchange for those parts already existing and already being integrated.

The relevant constraint is our limited VM time. Spending it assembling components we could
have had prebuilt is the wrong trade.

## 3. Addressing

| Host | VLAN | Address | Gateway |
|---|---|---|---|
| PacketFence | 60 | 10.50.60.10/24 | 10.50.60.1 |
| Keycloak | 60 | 10.50.60.20/24 | 10.50.60.1 |

Both static, inside the reserved .1 to .49 infrastructure range, consistent with the
addressing convention used across the design.

## 4. Onboarding flow

### 4.1 First connection, unregistered device

1. Device connects to the switch. No prior registration exists.
2. PacketFence does not recognise the device and places it in the registration role.
3. Device receives an address and its DNS and HTTP requests are intercepted.
4. The captive portal is presented.
5. The user authenticates against Keycloak using their university credentials.
6. Keycloak returns the user's identity and role: resident, staff or guest.
7. PacketFence binds the device to that user and stores the registration.
8. PacketFence issues a VLAN assignment for the role.
9. The device receives a new address in its assigned VLAN and has normal access.

### 4.2 Subsequent connections

1. Device connects.
2. PacketFence recognises the existing registration.
3. VLAN assignment is issued immediately.
4. Device is online. No portal, no re-authentication.

This is the property that makes the design usable. A student registers once at the start of
semester and the network behaves like home wifi afterwards, while the college retains a
record of which device belongs to whom.

### 4.3 Role to VLAN mapping

| Role | VLAN | Subnet |
|---|---|---|
| Resident, College A | 10 | 10.50.10.0/23 |
| Resident, College B | 11 | 10.50.12.0/23 |
| Resident, College C | 12 | 10.50.14.0/23 |
| Guest | 20 | 10.50.20.0/23 |
| Staff | 30 | 10.50.30.0/24 |
| Non-compliant or quarantined | 80 | 10.50.80.0/24 |

Which resident college a student belongs to is an attribute held in Keycloak, not something
PacketFence decides. This keeps the network out of the business of knowing who lives where.

## 5. Why identity and not MAC addresses

Modern phones generate a randomised MAC address per network and rotate it periodically. Any
design that treats one device as one permanent MAC breaks the first time a student's phone
rotates: the device stops being recognised, gets pushed back to the portal, and the
zero-touch reconnection promised above stops working.

Binding registration to an authenticated identity instead of a hardware address avoids this
entirely. It also produces a better security outcome, because access is removed by disabling
one account rather than by hunting for MAC addresses across an allow list, and it is what
makes per-device traceability meaningful.

## 6. Interface with monitoring and quarantine

The quarantine path crosses two components, so the boundary needs to be explicit.

| Step | Owner | Mechanism |
|---|---|---|
| Detect suspicious behaviour | Thevindu | Wazuh and Suricata on VLAN 70 |
| Raise an actionable event | Thevindu | Alert containing the offending IP address |
| Resolve address to registered device and user | Anshul | PacketFence registration record |
| Move the device to VLAN 80 | Anshul | RADIUS Change of Authorization, UDP 3799 |
| Enforce restricted policy | Josh | pfSense rules on VLAN 80 |
| Release once resolved | Anshul | Reassign to original role |

**The dependency to flag:** reassignment relies on RADIUS Change of Authorization, UDP 3799,
being permitted between VLAN 60 and the switch and firewall. Without CoA, PacketFence can
decide to quarantine a device but cannot move one that is already connected, so the device
stays where it is until it disconnects on its own. That would leave demo moment 3 partly
non-functional. It is covered in the firewall policy matrix and should be verified early
rather than discovered during integration.

## 7. Same-owner device grouping

The proposal states that devices registered to the same person can still reach each other,
so a student can cast from a laptop to their own TV while remaining isolated from every
other room.

This is harder than it reads. Blunt port isolation blocks all peer traffic within the VLAN
including a user's own devices, so this feature requires an exception keyed on registration
ownership rather than on address or port. Since PacketFence already knows which user each
device belongs to, the information exists, but translating it into per-owner layer 2
exceptions is a genuine piece of work.

**Recommendation:** treat basic resident-to-resident isolation as MVP and same-owner grouping
as a stretch goal, sequenced after isolation is demonstrably working. Attempting both at
once risks delivering neither, and isolation is the one the MVP actually requires.

## 8. Build sequence

| Step | Task | Depends on |
|---|---|---|
| 1 | Deploy PacketFence VM on VLAN 60 | Final VLAN interfaces on pfSense |
| 2 | Deploy Keycloak VM on VLAN 60 | Step 1 |
| 3 | Create resident, staff and guest test identities in Keycloak | Step 2 |
| 4 | Integrate PacketFence with Keycloak | Steps 1 to 3 |
| 5 | Stand up a two-client 802.1X test, no project topology | Step 4 |
| 6 | Configure the captive portal and registration | Step 5 |
| 7 | Configure role to VLAN mapping | Step 6 |
| 8 | Verify CoA reassignment works | Step 7 |
| 9 | Integrate with the live topology | Step 8, resident VLANs built |
| 10 | Write automation scripts so the component redeploys from the repository | Step 9 |

Step 5 matters. Validating 802.1X in a minimal two-client lab before touching the project
topology means that when something fails later, the authentication path is already known
good and the problem is isolated to integration.

## 9. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| PacketFence is resource-heavy and the EVE-NG host is shared | Install may not fit alongside other VMs | Check RAM headroom before deploying, raise with Josh early |
| CoA not permitted or not supported by Open vSwitch | Quarantine automation fails, demo moment 3 degraded | Verify at step 8, before integration. Manual reassignment as documented fallback |
| PacketFence and Keycloak integration is unfamiliar to me | Time overrun in Weeks 7 and 8 | Learning scheduled into the mid-term break, ahead of the build week |
| Limited weekly VM time | Component slips, blocking Thevindu | Steps 1 to 4 prepared offline as configuration files, applied inside the lab window |

## 10. Open questions

1. Does Open vSwitch in our build support the RADIUS CoA path PacketFence needs for dynamic
   reassignment, or does reassignment have to be scripted against OVS directly?
2. Do we need a separate pre-authentication onboarding VLAN, or does the PacketFence
   registration role handle it without one?
3. Is Keycloak in scope for the MVP, or is it a stretch goal? SSO is listed as stretch in the
   ED-1 brief, so committing to it needs a deliberate decision rather than drift.

## 11. Next steps

- Group review of this specification
- Confirm resource headroom on the EVE-NG host with Josh
- Verify CoA support before committing to automated quarantine
- Begin step 5, the minimal two-client authentication lab, once final VLAN interfaces exist

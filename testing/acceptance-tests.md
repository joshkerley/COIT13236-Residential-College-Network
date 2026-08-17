# Acceptance Tests

**Project:** Regional Uni Colleges, Secure High-Density Residential College Network
**Author:** Anshul Bairy (Onboarding and Access Control Lead)
**Date:** 17 August 2026
**Status:** Draft 1, for group review

---

## Purpose

These tests are written before the build rather than after it, so the network is measured
against a stated standard instead of a judgement made afterwards about whether it looks
right. Each test maps to one of the three demonstration moments in the ED-1 brief.

**Demo moment 1:** resident A cannot reach resident B
**Demo moment 2:** a new device onboards and lands on the correct VLAN
**Demo moment 3:** a compromised device is detected, quarantined and restored

A test passes only if the observed result matches the expected result exactly. Partial
passes are recorded as failures with a note, because a rule that works in one direction and
not the other is not a working control.

---

## Isolation tests (demo moment 1)

| ID | Test | Expected result | Status |
|----|------|-----------------|--------|
| T1 | Resident A client pings its own gateway 10.50.10.1 | Success | Not run |
| T2 | Resident A client pings Resident B client, both on VLAN 10 | Blocked | Not run |
| T3 | Resident A client reaches an external internet host | Success | Not run |
| T4 | Resident A client pings a host on VLAN 11 (College B) | Blocked | Not run |
| T5 | Resident A client attempts to reach Staff VLAN 30 | Blocked | Not run |
| T6 | Guest client reaches an external internet host | Success | Not run |
| T7 | Guest client pings any resident or internal server | Blocked | Not run |

### Note on T2

T2 is the test the current design fails without Open vSwitch port isolation. Two clients on
VLAN 10 exchange traffic through the switch at layer 2, so it never reaches pfSense and no
firewall rule can see it. A pfSense rule denying 10.50.10.0/23 to 10.50.10.0/23 has no
effect. This test must be run against OVS configuration, not firewall configuration.

---

## Onboarding tests (demo moment 2)

| ID | Test | Expected result | Status |
|----|------|-----------------|--------|
| T8 | Unregistered device connects to the network | Redirected to captive portal, no internal or internet access | Not run |
| T9 | Device authenticates with resident credentials | Assigned to VLAN 10, receives address in 10.50.10.0/23 | Not run |
| T10 | Previously registered device reconnects | Assigned automatically, no portal, no re-registration | Not run |
| T11 | Device authenticates with staff credentials | Assigned to VLAN 30, not VLAN 10 | Not run |

### Note on T10

T10 verifies the zero-touch reconnection the proposal commits to. It is also the test that
fails if registration is bound to a MAC address rather than to an authenticated identity,
because current mobile operating systems rotate their MAC per network. This test should be
repeated after a deliberate MAC change on the client.

---

## Abuse response tests (demo moment 3)

| ID | Test | Expected result | Status |
|----|------|-----------------|--------|
| T12 | Monitoring detects abnormal behaviour from a resident device | Alert raised in Wazuh identifying the source address | Not run |
| T13 | PacketFence issues reassignment for the flagged device | Device moves to VLAN 80 without disconnecting and reconnecting | Not run |
| T14 | Quarantined device attempts internal or internet access | Blocked, remediation page only | Not run |
| T15 | Device is cleared and released from quarantine | Returns to VLAN 10 with normal access restored | Not run |

### Note on T13

T13 depends on RADIUS Change of Authorization (UDP 3799) being permitted between the NAC
server on VLAN 60 and the switch and firewall. Without CoA, PacketFence can decide to
quarantine a device but cannot move one that is already connected, so the device keeps its
assignment until it disconnects on its own. This should be verified before automated
quarantine is committed to as an MVP item rather than a stretch goal.

---

## Test execution record

| Date | Tests run | Passed | Failed | Run by | Notes |
|------|-----------|--------|--------|--------|-------|
| | | | | | |

To be completed as the build progresses. Failures are to be recorded with the observed
result, not just marked as failed, so the cause can be traced.

---

## Dependencies

| Test range | Requires |
|------------|----------|
| T1 to T5 | Final VLAN interfaces on pfSense, resident test clients, OVS port isolation |
| T6 to T7 | Guest VLAN configured, guest test client |
| T8 to T11 | PacketFence and Keycloak deployed on VLAN 60, test identities created |
| T12 to T15 | Monitoring server on VLAN 70, quarantine VLAN 80, CoA verified |

T1 to T7 can be executed as soon as the core build is complete and do not depend on my
component. T8 onward depend on the NAC deployment described in `docs/nac-onboarding-design.md`.

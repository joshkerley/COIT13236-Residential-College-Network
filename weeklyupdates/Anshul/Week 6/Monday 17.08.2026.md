# Work Log, Anshul Bairy

## 17 August 2026 (Monday)

**Focus:** access control policy and NAC component specification.

### What I did

Went back through the network design against the ED-1 MVP requirements rather than just
checking the addressing. The addressing is fine, I verified every subnet boundary, gateway
placement and DHCP pool and they are all correct and non-overlapping. What was missing was
the policy layer. We have ten VLANs and a full IP plan but nowhere does the design say which
VLAN is allowed to reach which, and that policy is what the isolation and abuse
demonstrations are actually tested against.

Wrote the firewall and access control policy matrix to fill that gap. Default deny, then
explicit allows, expressed twice: a plain allow/deny grid for the group to agree on, and
per-VLAN rule detail with ports so it can be entered straight into pfSense without
re-deriving anything.

Also wrote the design specification for my own component, covering PacketFence and Keycloak
on VLAN 60, the onboarding flow for a first connection and for reconnection, role to VLAN
mapping, and where my component hands off to Thevindu's monitoring work.

Wrote 15 acceptance tests before starting the build so I am testing against a written
standard rather than deciding afterwards whether it looks right.

### Research

- **PacketFence vs FreeRADIUS.** FreeRADIUS is lighter but only does RADIUS. Registration,
  portal and quarantine would all have to be built separately. Given our lab time, taking
  the heavier install to get those prebuilt is the better trade. Agree with Josh's pick.
- **Open vSwitch port isolation.** OVS has no one-line equivalent to the protected port
  feature on physical switches. Isolation inside a VLAN is done with OpenFlow flow rules.
  This makes resident-to-resident isolation a bigger job than it first looked.
- **RADIUS Change of Authorization, UDP 3799.** This is how PacketFence moves a device that
  is already connected. Without it, a device flagged as compromised keeps its VLAN until it
  disconnects on its own.
- **MAC randomisation.** Phones rotate their MAC per network, so a MAC allow-list breaks the
  zero-touch reconnection we promised. Registration has to bind to an identity in Keycloak,
  not to hardware.

### Two findings worth flagging to the group

1. Resident-to-resident isolation cannot be done with pfSense rules. Two residents on VLAN
   10 talk through the switch and their traffic never reaches the gateway. It has to be OVS
   port isolation. A firewall rule denying 10.50.10.0/23 to itself does nothing.
2. Quarantine reassignment depends on UDP 3799 being permitted between VLAN 60 and the
   switch and firewall. If it is not, the automated quarantine part of demo moment 3 does
   not work.

### Blocked

PacketFence and Keycloak deployment cannot start until the final VLAN interfaces are up on
pfSense. Environment is still on temporary addressing.

### Next

- Network topology diagram, by 19 August
- Get the policy matrix agreed at the group meeting
- Verify whether OVS supports the CoA path PacketFence needs, by 22 August
- PacketFence and Keycloak learning across the mid-term break, ahead of the Week 7 build

### Honest note

Should have been writing this log from the start. I did design thinking over the past
fortnight but kept almost all of it in my head or in local files, which meant Josh ended up
researching the resident isolation approach himself and duplicating work I had already
done. Committing daily from here, finished or not.

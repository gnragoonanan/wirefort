# Security policy

WireFort deploys a VPN endpoint and a firewall. Please read this before
deploying it, and before reporting a problem with it.

## Reporting a vulnerability

**Do not open a public issue.**

Use GitHub's private vulnerability reporting:
[Report a vulnerability](https://github.com/gnragoonanan/wirefort/security/advisories/new)

> **Maintainer note:** private reporting must be switched on for this repository
> under *Settings → Code security and analysis → Private vulnerability
> reporting*, and a contact address added below, before this link works.

Please include:

- which component is affected (chart template, `init.sh`, `wg-install.sh`, the
  UFW policy, or the documentation)
- what an attacker can achieve, and what access they need to start
- a reproduction, redacted of real addresses and any key material
- your Kubernetes distribution, CNI and Multus version

Expect an acknowledgement within a few days. This is a spare-time project, so
please allow reasonable time for a fix before public disclosure.

### Report it upstream instead if

This project is largely glue around other people's software. Vulnerabilities in
the components themselves belong with their maintainers:

| Component | Where to report |
|---|---|
| WireGuard protocol or tooling | <https://www.wireguard.com/contact/> |
| wireguard-ui (the web interface) | <https://github.com/ngoduykhanh/wireguard-ui/security> |
| Nyr's installer, as shipped upstream | <https://github.com/Nyr/wireguard-install> |
| BoringTun | <https://github.com/cloudflare/boringtun/security> |
| The Debian base image | <https://github.com/j8r/dockerfiles> |
| Multus CNI | <https://github.com/k8snetworkplumbingwg/multus-cni/security> |

Report it **here** if the issue is in how WireFort wires those pieces together:
the firewall rules, the zone model, the chart's security context, secret
handling, the config-reload mechanism, or the documented defaults.

## Supported versions

| Version | Supported |
|---|---|
| `main` | Yes |
| Tagged releases | Latest tag only |

The chart is pre-1.0 (`version: 0.1.0`). There is no long-term support branch;
fixes land on `main`.

## Known risk profile

These are design properties of the chart as it stands, documented so you can
make an informed decision. They are **not** secrets and do not need to be
reported as vulnerabilities — though better solutions are very welcome as pull
requests.

| Property | Impact | Mitigation |
|---|---|---|
| Pod runs `privileged: true` with `NET_ADMIN` and `SYS_ADMIN`, plus a host `/sys/fs/cgroup` mount | Close to node-level access. A container escape is a node compromise. | Dedicate a namespace, restrict `exec` and `pods/exec` RBAC, keep unrelated workloads off these nodes |
| Default UI credentials are `admin` / `admin` | Trivial takeover of peer management if exposed | Change them before first exposure; move to a `Secret` with `valueFrom.secretKeyRef` |
| Credentials are plaintext env values in `values.yaml` | Readable by anyone with `get pod` or access to the release | Use a `Secret`; do not commit real credentials |
| wireguard-ui is served over plain HTTP on port 5000 | Credentials and peer keys in cleartext on the wire | Terminate TLS in front of it, or restrict it to a management network |
| `wg0.conf` holds the server private key on an NFS export | Anyone who can read the export can impersonate the server | Dedicated, access-controlled export; consider a local volume or encrypted transport |
| Packages and the BoringTun binary are fetched at every container start | Not reproducible; depends on upstream availability and integrity | Build a pre-baked image and pin versions |
| Images are unpinned (`latest` for the base, untagged for the UI) | Silent upstream changes | Pin both to digests |
| `init.sh` has no error handling around `ufw` calls | The pod can reach `Running` with a partial policy applied | **Always** verify with `ufw status numbered` after deploying |
| The pod is a bare `Pod`, not a controller | No rescheduling; a node failure takes the VPN down until manual action | Accept, or contribute the `StatefulSet` conversion |

## Deployment hardening checklist

Before exposing a WireFort pod to untrusted networks:

- [ ] Changed `WGUI_USERNAME` and `WGUI_PASSWORD`, sourced from a `Secret`
- [ ] UI reachable only from a management or DMZ network, not the internet
- [ ] TLS in front of the UI, or UI access restricted to a trusted network
- [ ] Verified the applied policy with `ufw status numbered` — not assumed
- [ ] **Tested the negative cases**: confirmed partner peers cannot reach the
      corporate network or the staff DMZ
- [ ] Container images pinned to digests
- [ ] NFS export restricted to the cluster nodes that need it
- [ ] RBAC limits who can `exec` into the pod
- [ ] Namespace is dedicated to this workload
- [ ] Peer revocation tested end to end, and verified the tunnel actually drops

## A note on the defaults

The addresses in `values.yaml` are RFC 5737 documentation and RFC 1918 private
ranges. They are examples and will not work on your network. Replace them —
including the copy inside `podAnnotations`, which is maintained separately from
`networks.macvlan.*`. A mismatch between those two produces a pod whose
addresses do not match its firewall rules, which is a security-relevant
misconfiguration rather than a cosmetic one.

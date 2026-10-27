# Contributing to WireFort

Thanks for considering a contribution. This project is a VPN and firewall
gateway, so a sloppy change can silently widen network access. The guidance
below exists mainly to prevent that.

## Ground rules

**Never commit real infrastructure.** No real IP addresses, VLAN names,
hostnames, NFS servers or organisation references. `values.yaml` is a sanitized
example and must stay that way — CI fails the build if it finds an address
outside RFC 1918 or the RFC 5737 documentation ranges.

Keep your own configuration in `values.yaml.working`, `my-values.yaml` or
`values.yaml.local`. All three are gitignored.

**Never commit key material.** No private keys, peer public keys, `wg0.conf`
files or client configs. CI greps for these too. `wg0.conf` contains the server
private key — treat it as a secret even in a log paste.

**Keep upstream copyright headers.** `wg-ufw/scripts/wg-install.sh` and the two
standalone `wireguard-install-*.sh` scripts are derivatives of
[Nyr/wireguard-install](https://github.com/Nyr/wireguard-install) under MIT.
The upstream notice at the top of each file is a license condition, not
decoration. Do not remove or reword it. See [NOTICE](NOTICE).

## Getting set up

You need `helm` 3 and `bash`. `shellcheck` and `kubeconform` are useful but CI
installs them for you.

```bash
git clone https://github.com/gnragoonanan/wirefort.git
cd wirefort
cp ufw-wg-pods/wg-ufw/values.yaml my-values.yaml   # then edit for your network
```

## Before you open a pull request

Run the same checks CI runs:

```bash
# Chart
helm lint ./ufw-wg-pods/wg-ufw
helm template test ./ufw-wg-pods/wg-ufw > /dev/null

# Scripts — syntax must pass, and init.sh must be clean at error severity
bash -n ufw-wg-pods/wg-ufw/scripts/*.sh
shellcheck --severity=error ufw-wg-pods/wg-ufw/scripts/init.sh

# Confirm nothing site-specific leaked into the packaged chart
helm package ./ufw-wg-pods/wg-ufw -d /tmp/pkg && tar -tzf /tmp/pkg/*.tgz
```

`wg-install.sh` and the standalone installers have inherited ShellCheck
findings from upstream. CI reports them but does not enforce them. Please don't
submit a mass-reformat of those files — it makes diffing against upstream
harder, which is the main reason we keep
`ufw-wg-pods/wireguard-install.sh.bkup` around.

## Changing the firewall policy

This deserves its own section because it is the easiest thing to get subtly
wrong.

The policy in `init.sh` ends with `ufw default reject routed`, so forwarding is
deny-by-default and every permitted path is an explicit `ufw route allow`. The
two peer zones are halves of the VPN subnet: `networks.wg.SE.nw` for staff and
`networks.wg.customer.nw` for customers and partners.

If you change any rule:

1. State in the PR what each zone can and cannot reach afterwards.
2. Paste `ufw status numbered` from a real deployment, with addresses redacted.
3. Test the **negative** cases. Confirming that staff access still works proves
   nothing about whether partner traffic is still contained. Say which denials
   you actually verified.
4. If you widen access by default, expect pushback. Prefer adding an opt-in
   value over loosening the shipped policy.

Note that `init.sh` currently flips the default from `allow routed` to
`reject routed` partway through, which makes the earlier `ufw route reject`
rules redundant by the time the script exits. Cleaning that up is welcome, but
it must not change the effective end state.

## Changing values.yaml

Two things are duplicated by design of the original chart, and both bite:

- `networks.macvlan.*` and the `k8s.v1.cni.cncf.io/networks` annotation in
  `podAnnotations` carry separate copies of the same addresses. If you change
  one, change the other. Templating the annotation so this can't desync is a
  genuinely wanted contribution.
- `wg-install.sh` hardcodes `10.10.10.x` addressing, so changing
  `networks.wg.nw` alone is not sufficient. Same for the DNS servers that
  `init.sh` writes directly into `/etc/resolv.conf`.

Adding or renaming a value is a breaking change for existing users. Say so in
the PR and in `CHANGELOG.md`, and bump `version` in `Chart.yaml`.

## Commit and PR conventions

- Bump `Chart.yaml` `version` for any change to templates, values or scripts.
  Bump `appVersion` only when the deployed application versions change.
- Add an entry under `## [Unreleased]` in `CHANGELOG.md`.
- Keep commits focused. Separate a refactor from a behaviour change.
- Say which Kubernetes distribution and CNI you tested against. "Untested on a
  cluster" is an acceptable answer for a docs or templating change — just be
  explicit so reviewers know what to check.

## Good first contributions

The README's **Known limitations** table is the backlog. The highest-value
items:

- Template `podAnnotations` from `networks.macvlan.*` to remove the duplication.
- Derive the VPN addressing in `wg-install.sh` from `networks.wg.nw`.
- Move `WGUI_USERNAME` / `WGUI_PASSWORD` into a `Secret` with
  `valueFrom.secretKeyRef`.
- Replace the bare `Pod` with a single-replica `StatefulSet`.
- Fix or remove `templates/tests/test-connection.yaml`, which targets a
  `Service` the chart never creates.
- Add a `values.schema.json` to catch misconfiguration before install.
- Offer a PVC alternative to the hardcoded NFS volumes.
- Build a pre-baked image so startup stops depending on live `apt` access.

## Reporting security issues

Do not open a public issue. See [SECURITY.md](SECURITY.md).

## Code of conduct

Participation is covered by our [Code of Conduct](CODE_OF_CONDUCT.md).

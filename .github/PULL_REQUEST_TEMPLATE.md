# Pull request

## What this changes

<!-- Describe the change and the problem it solves. Link the issue if there is one. -->

Closes #

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change to `values.yaml`
- [ ] Firewall or routing policy change
- [ ] Documentation only
- [ ] CI / tooling

## Verification

How did you test this? CI runs `helm lint`, renders the chart and syntax-checks
the scripts, but it cannot verify runtime behaviour on a real cluster.

- [ ] `helm lint ./ufw-wg-pods/wg-ufw` passes
- [ ] `helm template test ./ufw-wg-pods/wg-ufw` renders without error
- [ ] Deployed to a real cluster — distribution and CNI:
- [ ] Peers connect and reach the networks they should
- [ ] Peers are **blocked** from the networks they should not reach (say which you checked)
- [ ] Adding and revoking a peer in the UI applies without dropping existing tunnels
- [ ] Not deployed — rendering/docs change only

## Firewall policy changes

If you touched `init.sh` rules, paste the resulting `ufw status numbered` with
real addresses redacted, and state explicitly what each zone can and cannot
reach after your change. A policy change that silently widens access is the
most dangerous kind of regression in this project.

<!-- paste here, or write N/A -->

## Checklist

- [ ] No real addresses, VLAN names, hostnames or organisation references added
- [ ] No private keys, peer keys or client configs committed
- [ ] `values.yaml` still uses RFC 1918 or RFC 5737 documentation addresses only
- [ ] `networks.macvlan.*` and `podAnnotations` kept consistent if I changed either
- [ ] README updated if behaviour, values or limitations changed
- [ ] `CHANGELOG.md` updated under "Unreleased"
- [ ] `Chart.yaml` `version` bumped if chart templates or values changed
- [ ] Upstream copyright headers left intact in the derived installer scripts

# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the chart version follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Two versions are tracked separately:

- **Chart version** (`version` in `Chart.yaml`) — the packaging and templates.
  Bumped for any change to templates, values or scripts.
- **App version** (`appVersion`) — the deployed application stack. Bumped only
  when the images or installed software change.

---

## [Unreleased]

### Added

- `README.md` documenting the architecture, the two-tier UFW zone model, the
  live peer-reload mechanism, every `values.yaml` key, prerequisites,
  troubleshooting, security considerations and known limitations.
- Project identity: logo banner, architecture diagram and square chart icon
  under `docs/images/`.
- `LICENSE` (MIT) and `NOTICE` recording third-party components and the
  derivative relationship to Nyr's installer.
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` and this changelog.
- GitHub issue forms, pull request template, issue template config and
  Dependabot configuration under `.github/`.
- CI workflow (`.github/workflows/ci.yml`) covering:
  - `helm lint`, rendering with default and overridden values, and an assertion
    that the expected objects and both startup scripts are present
  - schema validation of rendered manifests with `kubeconform`
  - a packaging check that no local override or key material enters the archive
  - `bash -n` on all scripts; ShellCheck enforced at error severity on
    `init.sh` and advisory on the derived installers
  - repository hygiene gates: no `.DS_Store`, no tracked key material, no
    inline private keys, and `values.yaml` restricted to RFC 1918 / RFC 5737
    addresses
- `Chart.yaml` metadata: a real description, keywords, `home`, `sources`,
  `icon`, `maintainers` and Artifact Hub annotations.
- `.gitignore` covering site-specific overrides, key material, generated
  WireGuard configs, Helm archives, backups, macOS metadata and editor files.

### Changed

- **Sanitized `values.yaml`.** All 14 site-specific addresses replaced with
  RFC 5737 documentation and RFC 1918 private ranges, in both
  `networks.macvlan.*` and the `podAnnotations` copy. Added inline guidance
  covering the macvlan/annotation duplication, the default credentials, the
  unused scaffolding values and the NFS export requirements.
- Removed four organisation-specific references from `init.sh` comments and
  `ufw` rule comments. No rule logic changed.
- `.helmignore` now excludes local value overrides and generated key material
  from packaged charts.

### Preserved

- The original working configuration, with real site addresses, is kept at
  `ufw-wg-pods/wg-ufw/values.yaml.working`. It is gitignored and excluded from
  packaged charts — it must not be committed or published.

### Known issues

Carried forward and tracked in the README's *Known limitations* section:

- `networks.macvlan.*` and `podAnnotations` hold duplicate copies of the same
  addresses and must be edited together.
- `wg-install.sh` hardcodes `10.10.10.x` VPN addressing independently of
  `networks.wg.nw`.
- `init.sh` writes DNS servers directly to `/etc/resolv.conf` instead of using
  the `dns` environment variable it receives.
- The chart deploys a bare `Pod`; `replicaCount` is ignored.
- `service`, `ingress`, `autoscaling`, `nodeSelector`, `tolerations` and
  `affinity` are unused scaffolding.
- `templates/tests/test-connection.yaml` targets a `Service` the chart never
  creates, so `helm test` fails.
- `_helpers.tpl` defines `wg-ufw.serviceAccountName`, which reads a
  `.Values.serviceAccount` key that does not exist. Harmless only because
  nothing calls it.
- Rendered objects do not carry the `wg-ufw.labels` helper output, so
  `app.kubernetes.io/*` selectors will not match them.
- The reload scripts and cron jobs assume the interface is named `wg0`
  regardless of `networks.wg.wgif`.

---

## [0.1.0] — initial chart

### Added

- `wg-ufw` Helm chart deploying a two-container VPN gateway pod: a
  systemd-enabled Debian container running WireGuard and UFW, alongside the
  `wireguard-ui` web interface, sharing `/etc/wireguard` over NFS.
- Three `NetworkAttachmentDefinition`s providing external, internal/DMZ and
  corporate macvlan interfaces via Multus.
- `init.sh`, run from the pod's `postStart` hook: installs networking and
  firewall packages, invokes the WireGuard installer, applies the UFW zone
  policy with NAT and forwarding workarounds for a container where `sysctl`
  writes are refused, and installs the reload and cron units.
- `wg-install.sh`: Nyr's `wireguard-install` converted from interactive prompts
  to environment-variable input so it runs unattended, with the firewall logic
  separated out.
- Two-tier firewall zone model splitting the VPN subnet into a staff half and a
  customer/partner half, enforced with `ufw route` rules under a
  `default reject routed` policy.
- Live peer reload: `wg0.sh` plus a `wgui.path` / `wgui.service` systemd pair
  that diffs `wg0.conf` against its backup and applies peer additions and
  removals to the running interface without disrupting active tunnels.
- Scheduled `wg-quick` resets, weekly and monthly, via cron.
- `NOTES.txt` summarising the deployed interfaces, endpoint, VPN subnets, UI
  URL and credentials after install.
- Standalone `wireguard-install-GR-mod.sh` and `wireguard-install-env-auto.sh`
  for bare-metal and VM use, with an unmodified upstream copy kept at
  `wireguard-install.sh.bkup` for diffing.

[Unreleased]: https://github.com/gnragoonanan/wirefort/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gnragoonanan/wirefort/releases/tag/v0.1.0

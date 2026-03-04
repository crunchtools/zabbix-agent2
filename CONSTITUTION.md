# zabbix-agent2 Constitution

> **Version:** 1.0.0
> **Ratified:** 2026-03-04
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.0.0
> **Profile:** Container Image

## Image Purpose

Zabbix Agent2 7.0 on UBI 10 Minimal for host monitoring. Replaces the upstream `docker.io/zabbix/zabbix-agent2` Oracle Linux image with a consistent UBI 10 base.

## Base Image

`registry.access.redhat.com/ubi10/ubi-minimal` — agent2 is a single Go binary, no systemd needed.

## Packages

- `zabbix-agent2` from the official Zabbix 7.0 RPM repo (public, no RHSM required)

## Configuration

Default config at `/etc/zabbix/zabbix_agent2.conf` with include directory at `/etc/zabbix/zabbix_agent2.d/*.conf` for per-host overrides via volume mounts.

## Testing

- Static tests: verify packages, config, entrypoint, binary
- Runtime tests: verify agent2 starts and listens on port 10050

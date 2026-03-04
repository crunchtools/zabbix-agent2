# Zabbix Agent2 7.0 on UBI 10

Zabbix Agent2 container built on Red Hat Universal Base Image 10 Minimal. Designed for host monitoring with Docker/Podman container support.

## What's Inside

- **Zabbix Agent2 7.0** (from official Zabbix RPM repo)
- **UBI 10 Minimal** base (smallest footprint)
- Docker/Podman monitoring plugin (built into agent2 binary)

## Build

```bash
podman build -t localhost/zabbix-agent2:test -f Containerfile .
```

## Run

```bash
podman run -d \
    --name zabbix-agent \
    --network=host \
    --pid=host \
    --privileged \
    -v /srv/zabbix-agent/config/host.conf:/etc/zabbix/zabbix_agent2.d/host.conf:ro,Z \
    -v /:/host/rootfs:ro \
    -v /proc:/host/proc:ro \
    -v /sys:/host/sys:ro \
    -v /run/podman/podman.sock:/var/run/docker.sock:ro \
    quay.io/crunchtools/zabbix-agent2:latest
```

## Configuration

The default config sets `Hostname=localhost` and `Server=127.0.0.1`. Override by mounting a config file to `/etc/zabbix/zabbix_agent2.d/`:

```ini
Hostname=myhost.example.com
Server=127.0.0.1,10.88.0.1,10.88.0.11
ServerActive=127.0.0.1
```

## Systemd Deployment

A sample systemd unit and host config are in `deploy/`. To deploy:

```bash
cp deploy/zabbix-agent.service /etc/systemd/system/
mkdir -p /srv/zabbix-agent/config
cp deploy/lotor.conf /srv/zabbix-agent/config/  # edit for your host
systemctl daemon-reload
systemctl enable --now zabbix-agent.service
```

## Tests

```bash
./tests/test-image.sh --static localhost/zabbix-agent2:test
./tests/test-image.sh --runtime localhost/zabbix-agent2:test
./tests/test-image.sh --all localhost/zabbix-agent2:test
```

## Host Monitoring

The container needs these flags for full host visibility:

- `--network=host` — see real network interfaces and connections
- `--pid=host` — see real process table
- `--privileged` — full system access for monitoring
- Host filesystem mounts (`/`, `/proc`, `/sys`) — disk, CPU, memory metrics
- Podman socket mount — container monitoring via Docker-compatible API

## License

AGPL-3.0-or-later

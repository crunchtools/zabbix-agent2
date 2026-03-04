#!/bin/bash
# Test suite for Zabbix Agent2 7.0 UBI 10 container image
# Usage: ./tests/test-image.sh [--static|--runtime|--all] <image:tag>
set -euo pipefail

PASS=0
FAIL=0
MODE="all"
IMAGE=""

# Container runtime: honor env var, otherwise prefer podman
if [ -n "${CONTAINER_RUNTIME:-}" ]; then
    RUNTIME="$CONTAINER_RUNTIME"
elif command -v podman &>/dev/null; then
    RUNTIME="podman"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
else
    echo "ERROR: Neither podman nor docker found"
    exit 1
fi

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

check() {
    local desc="$1"; shift
    if eval "$@" >/dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --static)  MODE="static";  shift ;;
        --runtime) MODE="runtime"; shift ;;
        --all)     MODE="all";     shift ;;
        *)         IMAGE="$1";     shift ;;
    esac
done

if [[ -z "$IMAGE" ]]; then
    echo "Usage: $0 [--static|--runtime|--all] <image:tag>"
    exit 1
fi

# Helper: run a command inside the image (no daemon, just exec)
run_in() {
    $RUNTIME run --rm --entrypoint /bin/sh "$IMAGE" -c "$*"
}

# =============================================================================
# STATIC TESTS - verify image contents without starting the agent
# =============================================================================
run_static_tests() {
    echo ""
    echo "=== Static Tests ==="

    echo ""
    echo "--- Package Installation ---"
    check "zabbix-agent2 is installed" \
        run_in rpm -q zabbix-agent2

    echo ""
    echo "--- Zabbix Version ---"
    check "zabbix-agent2 is version 7.0.x" \
        'run_in rpm -q zabbix-agent2 | grep -q "^zabbix-agent2-7\.0\."'

    echo ""
    echo "--- Binary ---"
    check "zabbix_agent2 binary exists" \
        run_in test -f /usr/sbin/zabbix_agent2
    check "zabbix_agent2 binary is executable" \
        run_in test -x /usr/sbin/zabbix_agent2

    echo ""
    echo "--- Configuration Files ---"
    check "zabbix_agent2.conf exists" \
        run_in test -f /etc/zabbix/zabbix_agent2.conf
    check "zabbix.repo exists" \
        run_in test -f /etc/yum.repos.d/zabbix.repo
    check "Include directory exists" \
        run_in test -d /etc/zabbix/zabbix_agent2.d

    echo ""
    echo "--- Config Content ---"
    check "Hostname is set" \
        'run_in grep -q "^Hostname=" /etc/zabbix/zabbix_agent2.conf'
    check "Server is set" \
        'run_in grep -q "^Server=" /etc/zabbix/zabbix_agent2.conf'
    check "ServerActive is set" \
        'run_in grep -q "^ServerActive=" /etc/zabbix/zabbix_agent2.conf'
    check "Include directory is configured" \
        'run_in grep -q "^Include=/etc/zabbix/zabbix_agent2.d/" /etc/zabbix/zabbix_agent2.conf'
    check "Docker endpoint is configured" \
        'run_in grep -q "Plugins.Docker.Endpoint" /etc/zabbix/zabbix_agent2.conf'

    echo ""
    echo "--- Entrypoint ---"
    check "Entrypoint includes zabbix_agent2" \
        '$RUNTIME inspect --format="{{json .Config.Entrypoint}}" "$IMAGE" | grep -q "zabbix_agent2"'

    echo ""
    echo "--- OCI Labels ---"
    check "maintainer label is set" \
        '$RUNTIME inspect --format="{{index .Config.Labels \"maintainer\"}}" "$IMAGE" | grep -q "fatherlinux"'
    check "source label is set" \
        '$RUNTIME inspect --format="{{index .Config.Labels \"org.opencontainers.image.source\"}}" "$IMAGE" | grep -q "crunchtools/zabbix-agent2"'
}

# =============================================================================
# RUNTIME TESTS - start agent, verify it runs and listens
# =============================================================================
run_runtime_tests() {
    echo ""
    echo "=== Runtime Tests ==="

    local CONTAINER_NAME="zabbix-agent2-test-$$"

    echo ""
    echo "--- Starting agent container ---"

    # Start the agent in foreground mode (detached)
    $RUNTIME run -d \
        --name "$CONTAINER_NAME" \
        "$IMAGE"

    # Cleanup on exit
    trap "$RUNTIME rm -f $CONTAINER_NAME >/dev/null 2>&1 || true" EXIT

    # Wait for agent to start (up to 15s)
    # Note: ubi-minimal has no pgrep/ss, so use container runtime inspect
    echo "  Waiting for agent to start..."
    local ready=false
    for i in $(seq 1 15); do
        if $RUNTIME inspect --format='{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "true"; then
            ready=true
            break
        fi
        sleep 1
    done

    if ! $ready; then
        echo "  WARNING: agent did not start within 15s"
        echo "  DEBUG: container logs:"
        $RUNTIME logs "$CONTAINER_NAME" 2>&1 | tail -20 || true
    fi

    echo ""
    echo "--- Agent Process ---"
    check "Container is running (agent2 is PID 1)" \
        '$RUNTIME inspect --format="{{.State.Running}}" "$CONTAINER_NAME" | grep -q "true"'

    echo ""
    echo "--- Agent Port ---"
    # Wait for port binding (up to 10s)
    # 10050 decimal = 0x2742 hex; /proc/net/tcp is always available
    local port_ready=false
    for i in $(seq 1 10); do
        if $RUNTIME exec "$CONTAINER_NAME" sh -c "grep -qi ':2742' /proc/net/tcp6 2>/dev/null || grep -qi ':2742' /proc/net/tcp" 2>/dev/null; then
            port_ready=true
            break
        fi
        sleep 1
    done

    check "Agent listening on port 10050" \
        '$port_ready'

    # Cleanup
    $RUNTIME rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    trap - EXIT
}

# =============================================================================
# Main
# =============================================================================
echo "============================================"
echo "Zabbix Agent2 Container Image Tests"
echo "Image: $IMAGE"
echo "Mode:  $MODE"
echo "============================================"

if [[ "$MODE" == "static" || "$MODE" == "all" ]]; then
    run_static_tests
fi

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
    run_runtime_tests
fi

echo ""
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

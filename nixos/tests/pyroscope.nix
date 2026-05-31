{ pkgs, ... }:

{
  name = "pyroscope";

  meta.maintainers = [ pkgs.lib.maintainers.kashw2 ];

  nodes.machine =
    { ... }:
    {
      services.pyroscope = {
        enable = true;
        settings = {
          ingester.lifecycler = {
            address = "127.0.0.1";
            ring.replication_factor = 1;
          };

          # Each ring-aware component otherwise tries to auto-detect an IP
          # from `eth0`/`en0`, which is not reliable in the NixOS test VM.
          distributor.ring.instance_addr = "127.0.0.1";
          store_gateway.sharding_ring.instance_addr = "127.0.0.1";
          compactor.sharding_ring.instance_addr = "127.0.0.1";
          frontend.instance_addr = "127.0.0.1";
          query_scheduler.ring.instance_addr = "127.0.0.1";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("pyroscope.service")
    machine.wait_for_open_port(4040)

    with subtest("readiness probe responds"):
        machine.wait_until_succeeds(
            "curl --fail --silent http://localhost:4040/ready"
        )

    with subtest("Prometheus metrics endpoint is exposed"):
        machine.succeed(
            "curl --fail --silent --output /tmp/metrics.txt http://localhost:4040/metrics"
        )
        machine.succeed("grep -q '^pyroscope_' /tmp/metrics.txt")

    with subtest("admin page is reachable"):
        machine.succeed("curl --fail --silent http://localhost:4040/admin")

    with subtest("profilecli is installed alongside the server"):
        machine.succeed("profilecli --help")
  '';
}

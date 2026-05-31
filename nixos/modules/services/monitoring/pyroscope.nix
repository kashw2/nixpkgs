{
  lib,
  pkgs,
  config,
  utils,
  ...
}:

with lib;

let
  cfg = config.services.pyroscope;
  settingsFormat = pkgs.formats.yaml { };

  kvstoreOpts = {
    store = mkOption {
      type = types.enum [
        "consul"
        "etcd"
        "inmemory"
        "memberlist"
        "multi"
      ];
      default = "memberlist";
      description = "Backend storage to use for the ring.";
    };

    prefix = mkOption {
      type = types.str;
      default = "collectors/";
      description = "The prefix for the keys in the store. Should end with a slash.";
    };
  };

  ringOpts = {
    kvstore = kvstoreOpts;

    heartbeat_period = mkOption {
      type = types.str;
      default = "15s";
      description = "Period at which to heartbeat to the ring. 0 disables heartbeats.";
    };

    heartbeat_timeout = mkOption {
      type = types.str;
      default = "1m";
      description = ''
        The heartbeat timeout after which instances are assumed unhealthy
        within the ring. 0 = never (timeout disabled).
      '';
    };

    instance_id = mkOption {
      type = types.str;
      default = "";
      description = "Instance ID to register in the ring. Defaults to the hostname.";
    };

    instance_port = mkOption {
      type = types.port;
      default = 0;
      description = "Port to advertise in the ring. Defaults to the server gRPC listen port.";
    };

    instance_addr = mkOption {
      type = types.str;
      default = "";
      description = "IP address to advertise in the ring.";
    };

    instance_interface_names = mkOption {
      type = types.listOf types.str;
      default = [
        "eth0"
        "en0"
      ];
      description = "Network interfaces from which to read the instance address.";
    };

    instance_enable_ipv6 = mkOption {
      type = types.bool;
      default = false;
      description = "Enable using an IPv6 address from the interfaces above.";
    };
  };

  grpcClientOpts = {
    max_recv_msg_size = mkOption {
      type = types.int;
      default = 104857600;
      description = "gRPC client maximum receive message size, in bytes.";
    };

    max_send_msg_size = mkOption {
      type = types.int;
      default = 104857600;
      description = "gRPC client maximum send message size, in bytes.";
    };

    grpc_compression = mkOption {
      type = types.enum [
        ""
        "gzip"
        "snappy"
      ];
      default = "";
      description = "Compression to use for gRPC messages. Empty disables compression.";
    };

    rate_limit = mkOption {
      type = types.float;
      default = 0.0;
      description = "Rate limit, in requests per second. 0 disables the limit.";
    };

    rate_limit_burst = mkOption {
      type = types.int;
      default = 0;
      description = "Rate limit burst.";
    };

    backoff_on_ratelimits = mkOption {
      type = types.bool;
      default = false;
      description = "Enable backoff and retry when a rate limit is hit.";
    };

    connect_timeout = mkOption {
      type = types.str;
      default = "5s";
      description = "Maximum amount of time to establish a connection.";
    };

    tls_enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable TLS in the gRPC client.";
    };

    tls_cert_path = mkOption {
      type = types.str;
      default = "";
      description = "Path to the client certificate used for authentication.";
    };

    tls_key_path = mkOption {
      type = types.str;
      default = "";
      description = "Path to the private key for the client certificate.";
    };

    tls_ca_path = mkOption {
      type = types.str;
      default = "";
      description = "Path to the CA certificates used to validate the server certificate.";
    };

    tls_server_name = mkOption {
      type = types.str;
      default = "";
      description = "Override the expected name on the server certificate.";
    };

    tls_insecure_skip_verify = mkOption {
      type = types.bool;
      default = false;
      description = "Skip validation of the server certificate.";
    };
  };

  poolConfigOpts = {
    client_cleanup_period = mkOption {
      type = types.str;
      default = "15s";
      description = "How frequently to clean up clients for ingesters that have gone away.";
    };

    health_check_ingesters = mkOption {
      type = types.bool;
      default = true;
      description = "Run a health check on each ingester client during periodic cleanup.";
    };

    remote_timeout = mkOption {
      type = types.str;
      default = "5s";
      description = "Timeout for the gRPC health check.";
    };
  };

  tlsConfigOpts = {
    cert_file = mkOption {
      type = types.str;
      default = "";
      description = "Path to the server certificate.";
    };

    key_file = mkOption {
      type = types.str;
      default = "";
      description = "Path to the server private key.";
    };

    client_auth_type = mkOption {
      type = types.str;
      default = "";
      description = ''
        TLS client auth type. Allowed values: `NoClientCert`,
        `RequestClientCert`, `RequireAnyClientCert`,
        `VerifyClientCertIfGiven`, `RequireAndVerifyClientCert`.
      '';
    };

    client_ca_file = mkOption {
      type = types.str;
      default = "";
      description = "Path to the CA used to verify client certificates.";
    };
  };
in
{
  meta.maintainers = [ lib.maintainers.kashw2 ];

  options.services.pyroscope = {
    enable = mkEnableOption "Pyroscope";

    package = mkPackageOption pkgs "pyroscope" { };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for the Pyroscope HTTP listen port.";
    };

    settings = mkOption {
      default = { };
      description = ''
        Pyroscope server configuration in Nix. Rendered to YAML and passed via
        `--config.file`. The freeform type allows specifying any option not
        explicitly modeled below.

        Cannot be specified together with {option}`services.pyroscope.configFile`.

        See
        <https://grafana.com/docs/pyroscope/latest/configure-server/reference-configuration-parameters/>
        for the full list of available options.
      '';
      type = types.submodule {
        freeformType = settingsFormat.type;

        options = {
          target = mkOption {
            type = types.str;
            default = "all";
            description = ''
              Comma-separated list of Pyroscope modules to load. The alias `all`
              loads a sensible set of components and enables single-binary mode.
            '';
          };

          multitenancy_enabled = mkOption {
            type = types.bool;
            default = false;
            description = ''
              When enabled, requests to Pyroscope require an `X-Scope-OrgID`
              header specifying a tenant ID.
            '';
          };

          show_banner = mkOption {
            type = types.bool;
            default = true;
            description = "Display the application banner at startup.";
          };

          shutdown_delay = mkOption {
            type = types.str;
            default = "0s";
            description = ''
              How long to wait between SIGTERM and shutdown. After receiving
              SIGTERM, Pyroscope reports `not ready` via the readiness probe.
            '';
          };

          api.base-url = mkOption {
            type = types.str;
            default = "";
            description = ''
              Base URL where Pyroscope is being exposed. When set, all routes
              are served behind this prefix.
            '';
          };

          server = {
            http_listen_network = mkOption {
              type = types.enum [
                "tcp"
                "tcp4"
                "tcp6"
              ];
              default = "tcp";
              description = "HTTP server listen network.";
            };

            http_listen_address = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = ''
                HTTP server listen address.

                This setting intentionally varies from upstream's default
                (`""`) to be a bit more secure by default.
              '';
            };

            http_listen_port = mkOption {
              type = types.port;
              default = 4040;
              description = "HTTP server listen port.";
            };

            http_listen_conn_limit = mkOption {
              type = types.int;
              default = 0;
              description = "Maximum number of simultaneous HTTP connections. 0 disables the limit.";
            };

            grpc_listen_network = mkOption {
              type = types.enum [
                "tcp"
                "tcp4"
                "tcp6"
              ];
              default = "tcp";
              description = "gRPC server listen network.";
            };

            grpc_listen_address = mkOption {
              type = types.str;
              default = "";
              description = "gRPC server listen address.";
            };

            grpc_listen_port = mkOption {
              type = types.port;
              default = 9095;
              description = "gRPC server listen port.";
            };

            grpc_listen_conn_limit = mkOption {
              type = types.int;
              default = 0;
              description = "Maximum number of simultaneous gRPC connections. 0 disables the limit.";
            };

            tls_cipher_suites = mkOption {
              type = types.str;
              default = "";
              description = "Comma-separated list of TLS cipher suites. Empty uses the Go default.";
            };

            tls_min_version = mkOption {
              type = types.str;
              default = "";
              description = ''
                Minimum TLS version. Allowed values: `VersionTLS10`, `VersionTLS11`,
                `VersionTLS12`, `VersionTLS13`. Default is `VersionTLS12`.
              '';
            };

            http_tls_config = tlsConfigOpts;
            grpc_tls_config = tlsConfigOpts;

            graceful_shutdown_timeout = mkOption {
              type = types.str;
              default = "30s";
              description = "Timeout for graceful shutdowns.";
            };

            http_server_read_timeout = mkOption {
              type = types.str;
              default = "30s";
              description = "Read timeout for the HTTP server.";
            };

            http_server_read_header_timeout = mkOption {
              type = types.str;
              default = "0s";
              description = ''
                Read timeout for the HTTP request header. If 0,
                `http_server_read_timeout` is used.
              '';
            };

            http_server_write_timeout = mkOption {
              type = types.str;
              default = "30s";
              description = "Write timeout for the HTTP server.";
            };

            http_server_idle_timeout = mkOption {
              type = types.str;
              default = "2m";
              description = "Idle timeout for the HTTP server.";
            };

            http_log_closed_connections_without_response_enabled = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Log connections closed before sending a response, most likely
                because the client did not send any request within the timeout.
              '';
            };

            grpc_server_max_recv_msg_size = mkOption {
              type = types.int;
              default = 104857600;
              description = "Maximum size, in bytes, of a gRPC message this server can receive.";
            };

            grpc_server_max_send_msg_size = mkOption {
              type = types.int;
              default = 104857600;
              description = "Maximum size, in bytes, of a gRPC message this server can send.";
            };

            grpc_server_max_concurrent_streams = mkOption {
              type = types.int;
              default = 100;
              description = "Limit on the number of concurrent streams for gRPC calls per client connection. 0 = unlimited.";
            };

            grpc_server_keepalive_time = mkOption {
              type = types.str;
              default = "2h";
              description = "Duration after which a keepalive probe is sent if there is no activity over the connection.";
            };

            grpc_server_keepalive_timeout = mkOption {
              type = types.str;
              default = "20s";
              description = "After sending a keepalive probe, the duration after which an idle connection is closed.";
            };

            grpc_server_min_time_between_pings = mkOption {
              type = types.str;
              default = "10s";
              description = "Minimum time a client should wait before sending a keepalive ping.";
            };

            grpc_server_ping_without_stream_allowed = mkOption {
              type = types.bool;
              default = false;
              description = "Allow keepalive pings even when there are no active streams.";
            };

            grpc_server_num_workers = mkOption {
              type = types.int;
              default = 0;
              description = "If non-zero, the gRPC server uses the specified number of workers to process requests.";
            };

            grpc_server_recv_buffer_pools_enabled = mkOption {
              type = types.bool;
              default = false;
              description = "If true, the gRPC server uses a shared buffer pool for receiving data.";
            };

            grpc_server_stats_tracking_enabled = mkOption {
              type = types.bool;
              default = true;
              description = "If true, the gRPC server tracks stats.";
            };

            grpc_collect_max_streams_by_conn = mkOption {
              type = types.bool;
              default = true;
              description = "If true, the gRPC server collects per-connection max-stream metrics.";
            };

            log_format = mkOption {
              type = types.enum [
                "logfmt"
                "json"
              ];
              default = "logfmt";
              description = "Output log format.";
            };

            log_level = mkOption {
              type = types.enum [
                "debug"
                "info"
                "warn"
                "error"
              ];
              default = "info";
              description = "Logging level.";
            };

            log_source_ips_enabled = mkOption {
              type = types.bool;
              default = false;
              description = "Optionally log the source IPs of HTTP requests.";
            };

            log_source_ips_header = mkOption {
              type = types.str;
              default = "";
              description = "Header field storing the source IPs. Only used if `log_source_ips_enabled` is true.";
            };

            log_source_ips_regex = mkOption {
              type = types.str;
              default = "";
              description = "Regex for matching the source IPs. Only used if `log_source_ips_enabled` is true.";
            };

            log_request_headers = mkOption {
              type = types.bool;
              default = false;
              description = "Optionally log request headers.";
            };

            log_request_at_info_level_enabled = mkOption {
              type = types.bool;
              default = false;
              description = "Log requests at info level instead of debug.";
            };

            log_request_exclude_headers_list = mkOption {
              type = types.str;
              default = "";
              description = "Comma-separated list of headers to exclude from logging.";
            };

            register_instrumentation = mkOption {
              type = types.bool;
              default = true;
              description = "Register the instrumentation handlers (`/metrics` etc.).";
            };

            proxy_protocol_enabled = mkOption {
              type = types.bool;
              default = false;
              description = "Enable the PROXY protocol on the HTTP listener.";
            };

            http_path_prefix = mkOption {
              type = types.str;
              default = "";
              description = "Base path for all HTTP endpoints.";
            };
          };

          distributor = {
            pushtimeout = mkOption {
              type = types.str;
              default = "5s";
              description = "Timeout when pushing data to the ingester.";
            };

            pool_config = poolConfigOpts;
            ring = ringOpts;
          };

          ingester.lifecycler = {
            ring = {
              kvstore = kvstoreOpts;

              heartbeat_timeout = mkOption {
                type = types.str;
                default = "1m";
                description = "Timeout for ring heartbeats.";
              };

              replication_factor = mkOption {
                type = types.int;
                default = 1;
                description = "Number of ingesters to write to and read from.";
              };

              zone_awareness_enabled = mkOption {
                type = types.bool;
                default = false;
                description = "Enable zone awareness to replicate blocks across different availability zones.";
              };

              excluded_zones = mkOption {
                type = types.str;
                default = "";
                description = "Comma-separated list of zones to exclude from the ring.";
              };
            };

            num_tokens = mkOption {
              type = types.int;
              default = 128;
              description = "Number of tokens for each ingester.";
            };

            heartbeat_period = mkOption {
              type = types.str;
              default = "5s";
              description = "Period at which to heartbeat to the ring.";
            };

            heartbeat_timeout = mkOption {
              type = types.str;
              default = "1m";
              description = "Timeout for ring heartbeats.";
            };

            observe_period = mkOption {
              type = types.str;
              default = "0s";
              description = "Observe tokens after generating to resolve collisions. Useful when using a gossiping ring.";
            };

            join_after = mkOption {
              type = types.str;
              default = "0s";
              description = "Period to wait for a claim from another member before joining automatically.";
            };

            min_ready_duration = mkOption {
              type = types.str;
              default = "15s";
              description = ''
                Minimum duration to wait after the internal readiness checks have
                passed but before the readiness endpoint starts succeeding.
              '';
            };

            interface_names = mkOption {
              type = types.listOf types.str;
              default = [
                "eth0"
                "en0"
              ];
              description = "Name of network interfaces to read the address from.";
            };

            enable_inet6 = mkOption {
              type = types.bool;
              default = false;
              description = "Enable IPv6 support. Required for IPv6-only environments.";
            };

            final_sleep = mkOption {
              type = types.str;
              default = "0s";
              description = "Duration to sleep before exiting to ensure metrics are scraped.";
            };

            tokens_file_path = mkOption {
              type = types.str;
              default = "";
              description = "File path where tokens are stored.";
            };

            availability_zone = mkOption {
              type = types.str;
              default = "";
              description = "The availability zone where this instance is running.";
            };

            unregister_on_shutdown = mkOption {
              type = types.bool;
              default = true;
              description = "Unregister from the ring upon clean shutdown.";
            };

            readiness_check_ring_health = mkOption {
              type = types.bool;
              default = true;
              description = ''
                When true, the readiness probe succeeds only after all instances
                in the ring are ACTIVE and healthy.
              '';
            };

            address = mkOption {
              type = types.str;
              default = "";
              description = "IP address to advertise in the ring.";
            };
          };

          querier = {
            pool_config = poolConfigOpts;

            query_store_after = mkOption {
              type = types.str;
              default = "4h";
              description = ''
                Threshold after which queries also reach long-term storage
                instead of just ingesters. 0 sends all queries to the store.
              '';
            };
          };

          query_scheduler = {
            max_outstanding_requests_per_tenant = mkOption {
              type = types.int;
              default = 100;
              description = ''
                Maximum number of outstanding requests per tenant. In-flight
                requests above this limit fail with HTTP 429.
              '';
            };

            querier_forget_delay = mkOption {
              type = types.str;
              default = "0s";
              description = "Grace period for queriers that have disconnected from the scheduler. 0 disables it.";
            };

            max_used_instances = mkOption {
              type = types.int;
              default = 0;
              description = "Maximum number of query-scheduler instances used regardless of ring size. 0 = all.";
            };

            grpc_client_config = grpcClientOpts;

            service_discovery_mode = mkOption {
              type = types.enum [
                "dns"
                "ring"
              ];
              default = "ring";
              description = ''
                Service discovery mode used to find query-scheduler replicas.
                Pyroscope overrides dskit's `dns` default with `ring` so that
                single-binary mode works without an explicit scheduler address.
              '';
            };

            ring = ringOpts;
          };

          frontend = {
            scheduler_address = mkOption {
              type = types.str;
              default = "";
              description = "DNS hostname used for finding query-schedulers.";
            };

            scheduler_dns_lookup_period = mkOption {
              type = types.str;
              default = "10s";
              description = "How often to resolve `scheduler_address` to look for new query-scheduler instances.";
            };

            scheduler_worker_concurrency = mkOption {
              type = types.int;
              default = 5;
              description = "Number of concurrent workers forwarding queries to each query-scheduler.";
            };

            grpc_client_config = grpcClientOpts;

            instance_addr = mkOption {
              type = types.str;
              default = "";
              description = "IP address to advertise to the querier (via scheduler).";
            };

            instance_port = mkOption {
              type = types.int;
              default = 0;
              description = "Port to advertise to the querier (via scheduler).";
            };

            instance_interface_names = mkOption {
              type = types.listOf types.str;
              default = [
                "eth0"
                "en0"
              ];
              description = "List of interface names to look up to find the IP address to advertise.";
            };

            instance_enable_ipv6 = mkOption {
              type = types.bool;
              default = false;
              description = "Enable using an IPv6 instance address.";
            };
          };

          frontend_worker = {
            scheduler_address = mkOption {
              type = types.str;
              default = "";
              description = "Hostname (and port) of the scheduler that the querier periodically requests jobs from.";
            };

            dns_lookup_duration = mkOption {
              type = types.str;
              default = "10s";
              description = "How often to query DNS for the query-frontend or query-scheduler address.";
            };

            id = mkOption {
              type = types.str;
              default = "";
              description = "Querier ID, sent to the query-frontend. Defaults to the hostname.";
            };

            grpc_client_config = grpcClientOpts;

            max_concurrent = mkOption {
              type = types.int;
              default = 4;
              description = "Number of simultaneous queries to process per query-frontend or query-scheduler.";
            };
          };

          store_gateway = {
            sharding_ring = ringOpts // {
              replication_factor = mkOption {
                type = types.int;
                default = 1;
                description = "Number of store-gateways to replicate blocks to.";
              };

              tokens_file_path = mkOption {
                type = types.str;
                default = "";
                description = "File path where tokens are stored.";
              };

              zone_awareness_enabled = mkOption {
                type = types.bool;
                default = false;
                description = "Enable zone awareness for block replication across availability zones.";
              };

              instance_availability_zone = mkOption {
                type = types.str;
                default = "";
                description = "The availability zone where this instance is running.";
              };

              unregister_on_shutdown = mkOption {
                type = types.bool;
                default = true;
                description = "Unregister from the ring upon clean shutdown.";
              };

              wait_stability_min_duration = mkOption {
                type = types.str;
                default = "0s";
                description = "Minimum time to wait for ring stability at startup. 0 disables this check.";
              };

              wait_stability_max_duration = mkOption {
                type = types.str;
                default = "5m";
                description = "Maximum time to wait for ring stability at startup.";
              };
            };

            bucket_store = {
              sync_dir = mkOption {
                type = types.str;
                default = "./data/pyroscope-sync/";
                description = "Directory used to store synchronized Pyroscope block headers.";
              };

              sync_interval = mkOption {
                type = types.str;
                default = "15m";
                description = "How frequently to scan the bucket for new blocks.";
              };

              tenant_sync_concurrency = mkOption {
                type = types.int;
                default = 10;
                description = "Maximum number of concurrent tenants synchronized at once.";
              };

              meta_sync_concurrency = mkOption {
                type = types.int;
                default = 20;
                description = "Maximum number of concurrent goroutines used to fetch block metadata.";
              };

              ignore_blocks_within = mkOption {
                type = types.str;
                default = "3h";
                description = "Blocks with a maximum time within this duration are ignored.";
              };

              ignore_deletion_mark_delay = mkOption {
                type = types.str;
                default = "30m";
                description = "Duration after which blocks marked for deletion are filtered out while fetching.";
              };
            };
          };

          compactor = {
            block_ranges = mkOption {
              type = types.listOf types.str;
              default = [
                "1h0m0s"
                "2h0m0s"
                "8h0m0s"
              ];
              description = "List of compaction time ranges.";
            };

            block_sync_concurrency = mkOption {
              type = types.int;
              default = 8;
              description = ''
                Number of goroutines used to download blocks for compaction and
                upload the resulting blocks.
              '';
            };

            meta_sync_concurrency = mkOption {
              type = types.int;
              default = 20;
              description = "Number of goroutines used to sync block meta files from object storage.";
            };

            data_dir = mkOption {
              type = types.str;
              default = "./data-compactor";
              description = "Data directory for the compactor.";
            };

            compaction_interval = mkOption {
              type = types.str;
              default = "30m";
              description = "Frequency at which compaction runs.";
            };

            compaction_retries = mkOption {
              type = types.int;
              default = 3;
              description = "Number of retry attempts on a failed compaction within a single compaction run.";
            };

            compaction_concurrency = mkOption {
              type = types.int;
              default = 1;
              description = "Maximum number of concurrent compactions.";
            };

            cleanup_interval = mkOption {
              type = types.str;
              default = "15m";
              description = "How frequently the compactor should run blocks cleanup and maintenance.";
            };

            cleanup_concurrency = mkOption {
              type = types.int;
              default = 20;
              description = "Max number of tenants for which blocks cleanup and maintenance is run concurrently.";
            };

            deletion_delay = mkOption {
              type = types.str;
              default = "12h";
              description = "Time before a block marked for deletion is deleted from the bucket.";
            };

            tenant_cleanup_delay = mkOption {
              type = types.str;
              default = "6h";
              description = "For tenants marked for deletion, the time after which block deletions are performed.";
            };

            max_compaction_time = mkOption {
              type = types.str;
              default = "1h";
              description = "Maximum duration of a single compaction.";
            };

            first_level_compaction_wait_period = mkOption {
              type = types.str;
              default = "25m";
              description = ''
                How long the compactor waits before compacting first-level
                blocks produced by ingesters.
              '';
            };

            downsampler_enabled = mkOption {
              type = types.bool;
              default = false;
              description = ''
                When enabled, profiles in blocks at compaction level 3 or higher
                are downsampled to reduce storage size and improve query
                performance.
              '';
            };

            enabled_tenants = mkOption {
              type = types.str;
              default = "";
              description = "Comma-separated list of tenants that can be compacted. Empty means all.";
            };

            disabled_tenants = mkOption {
              type = types.str;
              default = "";
              description = "Comma-separated list of tenants that cannot be compacted.";
            };

            sharding_ring = ringOpts // {
              wait_stability_min_duration = mkOption {
                type = types.str;
                default = "0s";
                description = "Minimum time to wait for ring stability at startup.";
              };

              wait_stability_max_duration = mkOption {
                type = types.str;
                default = "5m";
                description = "Maximum time to wait for ring stability at startup.";
              };

              wait_active_instance_timeout = mkOption {
                type = types.str;
                default = "10m";
                description = "Timeout for waiting on the compactor to become ACTIVE in the ring.";
              };
            };
          };

          memberlist = {
            node_name = mkOption {
              type = types.str;
              default = "";
              description = "Name of the node in the memberlist cluster. Defaults to the hostname.";
            };

            randomize_node_name = mkOption {
              type = types.bool;
              default = true;
              description = "Add a random suffix to the node name.";
            };

            stream_timeout = mkOption {
              type = types.str;
              default = "2s";
              description = "Timeout for establishing a connection with a remote node and for read/write.";
            };

            retransmit_factor = mkOption {
              type = types.int;
              default = 4;
              description = "Multiplication factor used when sending out messages (retransmits = factor * log(N+1)).";
            };

            pull_push_interval = mkOption {
              type = types.str;
              default = "30s";
              description = "How often to use pull/push sync.";
            };

            gossip_interval = mkOption {
              type = types.str;
              default = "200ms";
              description = "How often to gossip.";
            };

            gossip_nodes = mkOption {
              type = types.int;
              default = 3;
              description = "How many nodes to gossip to.";
            };

            gossip_to_dead_nodes_time = mkOption {
              type = types.str;
              default = "30s";
              description = "How long to keep gossiping to dead nodes, to give them a chance to refute their death.";
            };

            dead_node_reclaim_time = mkOption {
              type = types.str;
              default = "0s";
              description = "How soon a dead node's name can be reclaimed with a new address. 0 disables reclamation.";
            };

            compression_enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Enable message compression.";
            };

            advertise_addr = mkOption {
              type = types.str;
              default = "";
              description = "Gossip address advertised to other nodes.";
            };

            advertise_port = mkOption {
              type = types.port;
              default = 7946;
              description = "Gossip port advertised to other nodes (helps with NAT traversal).";
            };

            cluster_label = mkOption {
              type = types.str;
              default = "";
              description = "Optional label used to detect misconfigured cluster joins.";
            };

            cluster_label_verification_disabled = mkOption {
              type = types.bool;
              default = false;
              description = "When true, memberlist does not verify cluster labels.";
            };

            join_members = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "pyroscope-memberlist.svc.cluster.local:7946" ];
              description = ''
                Other cluster members to join. Can be specified multiple times
                as an IP, hostname, or DNS Service Discovery entry.
              '';
            };

            min_join_backoff = mkOption {
              type = types.str;
              default = "1s";
              description = "Minimum backoff duration when joining cluster members.";
            };

            max_join_backoff = mkOption {
              type = types.str;
              default = "1m";
              description = "Maximum backoff duration when joining cluster members.";
            };

            max_join_retries = mkOption {
              type = types.int;
              default = 10;
              description = "Maximum number of retries when joining cluster members.";
            };

            abort_if_cluster_join_fails = mkOption {
              type = types.bool;
              default = false;
              description = "If this node fails to join the memberlist cluster, abort.";
            };

            rejoin_interval = mkOption {
              type = types.str;
              default = "0s";
              description = "If non-zero, how often to rejoin the cluster.";
            };

            left_ingesters_timeout = mkOption {
              type = types.str;
              default = "5m";
              description = "How long to keep LEFT ingesters in the ring.";
            };

            leave_timeout = mkOption {
              type = types.str;
              default = "20s";
              description = "Timeout for leaving the memberlist cluster.";
            };

            message_history_buffer_bytes = mkOption {
              type = types.int;
              default = 0;
              description = "Bytes to use for the message history buffer. 0 disables it.";
            };

            bind_addr = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "IP addresses to listen on for gossip messages. Empty = all addresses.";
            };

            bind_port = mkOption {
              type = types.port;
              default = 7946;
              description = "Port to listen on for gossip messages.";
            };

            packet_dial_timeout = mkOption {
              type = types.str;
              default = "2s";
              description = "Timeout used when connecting to other nodes to send a packet.";
            };

            packet_write_timeout = mkOption {
              type = types.str;
              default = "5s";
              description = "Timeout for writing packet data.";
            };

            tls_enabled = mkOption {
              type = types.bool;
              default = false;
              description = "Enable TLS for memberlist communications.";
            };

            tls_cert_path = mkOption {
              type = types.str;
              default = "";
              description = "Path to the client certificate file.";
            };

            tls_key_path = mkOption {
              type = types.str;
              default = "";
              description = "Path to the private key file.";
            };

            tls_ca_path = mkOption {
              type = types.str;
              default = "";
              description = "Path to the CA certificates file.";
            };

            tls_server_name = mkOption {
              type = types.str;
              default = "";
              description = "Override the expected name on the server certificate.";
            };

            tls_insecure_skip_verify = mkOption {
              type = types.bool;
              default = false;
              description = "Skip validation of the server certificate.";
            };
          };

          limits = {
            ingestion_rate_mb = mkOption {
              type = types.float;
              default = 4.0;
              description = "Per-tenant ingestion rate limit, in megabytes per second.";
            };

            ingestion_burst_size_mb = mkOption {
              type = types.float;
              default = 2.0;
              description = "Per-tenant allowed ingestion burst size, in megabytes.";
            };

            ingestion_body_limit_mb = mkOption {
              type = types.float;
              default = 0.0;
              description = "Per-tenant ingestion body limit, in megabytes. 0 disables the limit.";
            };

            ingestion_tenant_shard_size = mkOption {
              type = types.int;
              default = 0;
              description = "The tenant's shard size used by shuffle-sharding. 0 disables shuffle sharding.";
            };

            max_label_name_length = mkOption {
              type = types.int;
              default = 1024;
              description = "Maximum length accepted for label names.";
            };

            max_label_value_length = mkOption {
              type = types.int;
              default = 2048;
              description = "Maximum length accepted for label values.";
            };

            max_label_names_per_series = mkOption {
              type = types.int;
              default = 30;
              description = "Maximum number of label names per series.";
            };

            max_profile_size_bytes = mkOption {
              type = types.int;
              default = 4194304;
              description = "Maximum size of a profile, in bytes (4 MiB).";
            };

            max_profile_stacktrace_samples = mkOption {
              type = types.int;
              default = 16000;
              description = "Maximum number of samples in a profile.";
            };

            max_profile_stacktrace_sample_labels = mkOption {
              type = types.int;
              default = 100;
              description = "Maximum number of labels in a stacktrace sample.";
            };

            max_profile_stacktrace_depth = mkOption {
              type = types.int;
              default = 1000;
              description = "Maximum number of frames in a stacktrace.";
            };

            max_profile_symbol_value_length = mkOption {
              type = types.int;
              default = 65535;
              description = "Maximum length of a symbol value.";
            };

            enforce_labels_order = mkOption {
              type = types.bool;
              default = false;
              description = "When true, labels in a profile must be in alphabetical order.";
            };

            reject_older_than = mkOption {
              type = types.str;
              default = "1h";
              description = "Reject profiles with samples older than this duration.";
            };

            reject_newer_than = mkOption {
              type = types.str;
              default = "10m";
              description = "Reject profiles with samples newer than this duration in the future.";
            };

            max_query_lookback = mkOption {
              type = types.str;
              default = "7d";
              description = "Maximum lookback for queries. 0 disables the limit.";
            };

            max_query_length = mkOption {
              type = types.str;
              default = "1d";
              description = "Maximum duration of a single query. 0 disables the limit.";
            };

            max_query_parallelism = mkOption {
              type = types.int;
              default = 0;
              description = "Maximum number of queries scheduled in parallel by the frontend. 0 disables it.";
            };

            max_flamegraph_nodes_default = mkOption {
              type = types.int;
              default = 8192;
              description = "Default maximum number of flamegraph nodes.";
            };

            max_flamegraph_nodes_max = mkOption {
              type = types.int;
              default = 1048576;
              description = "Hard maximum number of flamegraph nodes allowed.";
            };

            query_analysis_enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Whether the AnalyzeQuery API is enabled.";
            };

            query_analysis_series_enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Whether the AnalyzeQuery API includes a series analysis.";
            };

            split_queries_by_interval = mkOption {
              type = types.str;
              default = "0s";
              description = "Split queries by an interval and execute them in parallel. 0 disables splitting.";
            };

            max_local_series_per_tenant = mkOption {
              type = types.int;
              default = 0;
              description = "Maximum number of active series per tenant, per ingester. 0 disables the limit.";
            };

            max_global_series_per_tenant = mkOption {
              type = types.int;
              default = 5000;
              description = "Maximum number of active series per tenant across the cluster. 0 disables it.";
            };

            max_sessions_per_series = mkOption {
              type = types.int;
              default = 0;
              description = "Maximum number of sessions supported per series. 0 disables session-based limiting.";
            };

            store_gateway_tenant_shard_size = mkOption {
              type = types.int;
              default = 0;
              description = "The tenant's shard size for the store-gateway. 0 disables shuffle sharding.";
            };

            compactor_blocks_retention_period = mkOption {
              type = types.str;
              default = "0s";
              description = "Delete blocks with samples older than this. 0 disables retention.";
            };

            compactor_split_and_merge_shards = mkOption {
              type = types.int;
              default = 0;
              description = "Number of shards used by the split-and-merge compactor strategy. 0 disables it.";
            };

            compactor_split_and_merge_stage_size = mkOption {
              type = types.int;
              default = 0;
              description = "Number of stages the split shards are written to.";
            };

            compactor_tenant_shard_size = mkOption {
              type = types.int;
              default = 0;
              description = "Maximum number of compactors that can compact blocks for a single tenant. 0 = unlimited.";
            };

            compactor_downsampler_enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Whether the downsampler is enabled for this tenant.";
            };

            ingestion_relabeling_rules = mkOption {
              type = types.listOf settingsFormat.type;
              default = [ ];
              description = "List of ingestion relabel configurations.";
            };

            ingestion_relabeling_default_rules_position = mkOption {
              type = types.enum [
                "first"
                "last"
                "disabled"
              ];
              default = "first";
              description = "Position of the default relabeling rules.";
            };

            distributor_aggregation_window = mkOption {
              type = types.str;
              default = "0s";
              description = "Duration of the distributor's aggregation window.";
            };

            distributor_aggregation_period = mkOption {
              type = types.str;
              default = "0s";
              description = "Duration of the distributor's aggregation period.";
            };

            sample_type_relabeling_rules = mkOption {
              type = types.listOf settingsFormat.type;
              default = [ ];
              description = "List of sample-type relabel configurations.";
            };
          };

          pyroscopedb = {
            data_path = mkOption {
              type = types.str;
              default = "./data";
              description = "Directory used for local storage.";
            };

            max_block_duration = mkOption {
              type = types.str;
              default = "1h";
              description = "Maximum block duration.";
            };

            row_group_target_size = mkOption {
              type = types.int;
              default = 1342177280;
              description = "Target uncompressed row group size, in bytes.";
            };

            symbols_partition_label = mkOption {
              type = types.str;
              default = "";
              description = "Label used to partition stacktraces into compact tries (e.g. `service_name`).";
            };

            min_free_disk_gb = mkOption {
              type = types.int;
              default = 10;
              description = "Disk space to keep free, in GiB.";
            };

            min_disk_available_percentage = mkOption {
              type = types.float;
              default = 0.05;
              description = "Percentage of disk to keep free, expressed as a fraction.";
            };

            enforcement_interval = mkOption {
              type = types.str;
              default = "5m";
              description = "Frequency of retention enforcement checks.";
            };

            disable_enforcement = mkOption {
              type = types.bool;
              default = false;
              description = "Disable retention policy enforcement.";
            };
          };

          storage = {
            backend = mkOption {
              type = types.enum [
                "s3"
                "gcs"
                "azure"
                "swift"
                "filesystem"
                "cos"
              ];
              default = "filesystem";
              description = "Object storage backend type.";
            };

            prefix = mkOption {
              type = types.str;
              default = "";
              description = "Prefix used for all objects stored in object storage.";
            };

            filesystem.dir = mkOption {
              type = types.str;
              default = "./data-shared";
              description = "Local filesystem storage directory.";
            };
          };

          tracing = {
            enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Set to false to disable tracing.";
            };

            profiling_enabled = mkOption {
              type = types.bool;
              default = true;
              description = "When enabled, include profile IDs in traces.";
            };
          };

          runtime_config = {
            period = mkOption {
              type = types.str;
              default = "10s";
              description = "How often to reload the runtime config file.";
            };

            file = mkOption {
              type = types.str;
              default = "";
              description = "Comma-separated list of YAML files holding configuration that can be updated at runtime.";
            };
          };

          self_profiling = {
            disable_push = mkOption {
              type = types.bool;
              default = false;
              description = "Disable pushing self-profiles to the upstream instance.";
            };

            mutex_profile_fraction = mkOption {
              type = types.int;
              default = 5;
              description = "Sampling rate for mutex profile collection (1/N events).";
            };

            block_profile_rate = mkOption {
              type = types.int;
              default = 5;
              description = "Sampling rate (nanoseconds) for the block profile.";
            };

            use_k6_middleware = mkOption {
              type = types.bool;
              default = false;
              description = "Pick up k6 labels from k6-specific HTTP headers.";
            };

            tenant_id = mkOption {
              type = types.str;
              default = "";
              description = "Tenant used when self-profiling pushes occur.";
            };
          };

          embedded_grafana = {
            data_path = mkOption {
              type = types.str;
              default = "./data/__embedded_grafana/";
              description = "Directory for the embedded Grafana data.";
            };

            listen_port = mkOption {
              type = types.port;
              default = 4041;
              description = "Port the embedded Grafana listens on.";
            };

            pyroscope_url = mkOption {
              type = types.str;
              default = "http://localhost:4040";
              description = "URL to the Pyroscope datasource.";
            };
          };
        };
      };
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a configuration file that Pyroscope should use.

        When set, this file is passed via `--config.file` and
        {option}`services.pyroscope.settings` is ignored.
      '';
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional arguments to pass to pyroscope.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.pyroscope = {
      description = "Grafana Pyroscope Service Daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig =
        let
          conf =
            if cfg.configFile != null then
              cfg.configFile
            else
              settingsFormat.generate "config.yaml" cfg.settings;
        in
        {
          ExecStart = utils.escapeSystemdExecArgs (
            [
              "${getExe cfg.package}"
              "--config.file=${conf}"
            ]
            ++ cfg.extraFlags
          );
          DynamicUser = true;
          ProtectSystem = "full";
          DevicePolicy = "closed";
          WorkingDirectory = "/var/lib/pyroscope";
          StateDirectory = "pyroscope";
          Restart = "on-failure";
        };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.settings.server.http_listen_port
    ];
  };
}

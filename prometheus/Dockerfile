# Pin to a specific Prometheus version for reproducibility.
# Never use "latest" in production — a Prometheus update could change
# default configs, metric names, or behavior and silently break your stack.
# Check for new versions at: https://github.com/prometheus/prometheus/releases
FROM prom/prometheus:v2.51.0

# Override the default config with our custom scrape targets.
# /etc/prometheus/prometheus.yml is where Prometheus looks by default.
COPY prometheus.yml /etc/prometheus/prometheus.yml

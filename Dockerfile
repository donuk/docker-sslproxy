FROM caddy:2

RUN cat > /entrypoint.sh <<'EOF'
#!/bin/sh
set -e

cat > /etc/caddy/Caddyfile <<CADDYFILE
$DOMAIN {
		reverse_proxy $BACKEND
}
CADDYFILE

echo "Caddyfile generated with DOMAIN=${DOMAIN} and BACKEND=${BACKEND}:"
cat /etc/caddy/Caddyfile

"$@"
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

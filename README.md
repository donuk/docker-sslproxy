Also on dockerhub:

https://hub.docker.com/r/donuk/sslproxy

This attempts to auto-configure an ssl proxy using caddy, it's basically a wrapper around https://hub.docker.com/_/caddy but can be configured entirely with environment variables which I find useful.

To proxy http://example.com and make it visible at https://my-domain.com.

```
docker run -p 443:443 -p 80:80 -v $PWD/persisted-ssl-files:/data -e BACKEND=example.com DOMAIN=my-domain.com --rm donuk/sslproxy
```

The SSL configuration will only work if the container is accessible at my-domain.com. If the automatic Let's Encrypt SSL certificate fails (for example, if the domain is not accessible), the container will automatically fall back to a self-signed SSL certificate.

## IP restriction

Set `ALLOWED_IPS` to a comma-separated list of allowed IPv4/IPv6 addresses or CIDR ranges. Requests from other client IPs receive `403`.

Set `DEBUG_BLOCKED_IPS=true` to emit Caddy access logs and append the blocked client IP to denied requests.

```
docker run -p 443:443 -p 80:80 -v $PWD/persisted-ssl-files:/data \
  -e BACKEND=example.com \
  -e DOMAIN=my-domain.com \
  -e ALLOWED_IPS="203.0.113.10,2001:db8::/32,10.0.0.0/8" \
  --rm donuk/sslproxy
```

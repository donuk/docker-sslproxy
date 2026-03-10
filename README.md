Also on dockerhub:

https://hub.docker.com/r/donuk/sslproxy

This attempts to auto-configure an ssl proxy using caddy, it's basically a wrapper around https://hub.docker.com/_/caddy but can be configured entirely with environment variables which I find useful.

To proxy http://example.com and make it visible at https://my-domain.com.

```
docker run -p 443:443 -p 80:80 -e BACKEND=example.com DOMAIN=my-domain.com --rm donuk/selfsignedhttpsproxy
```

The SSL configuration will only work if the container is accessible at my-domain.com, otherwise this will fail to boot.  I should add a failover to self signed SSL really, but that's a job for later.

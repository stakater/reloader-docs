# syntax=docker/dockerfile:1
FROM nginxinc/nginx-unprivileged:1.27-alpine
WORKDIR /usr/share/nginx/html/

# copy the entire application
COPY --from=content --chown=1001:root . .

COPY default.conf /etc/nginx/conf.d/

# set non-root user
USER 1001

LABEL name="Stakater Cloud Orchestrator Documentation" \
      maintainer="Stakater <hello@stakater.com>" \
      vendor="Stakater" \
      release="1" \
      summary="Documentation for Stakater Cloud Orchestrator"

EXPOSE 8080:8080/tcp

CMD ["nginx", "-g", "daemon off;"]
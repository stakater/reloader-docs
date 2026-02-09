# syntax=docker/dockerfile:1

############################
# Builder: build MkDocs site
############################
FROM python:3.12-alpine AS builder

ENV HOME=/home/1001
ENV APP_DIR=${HOME}/application
WORKDIR ${APP_DIR}

# Tools needed for python wheels + optional theme clone
RUN apk add --no-cache \
      git \
      build-base \
      libffi-dev \
      openssl-dev

# Copy repo
COPY --chown=1001:root . .

# Ensure theme_common exists (supports ZIP checkouts / missing submodule)
# If theme_common/requirements.txt is missing, clone the shared theme.
ARG THEME_REPO=https://github.com/stakater/stakater-docs-mkdocs-theme.git
ARG THEME_REF=main

RUN if [ ! -f theme_common/requirements.txt ]; then \
      echo "theme_common missing -> cloning ${THEME_REPO} (${THEME_REF})"; \
      rm -rf theme_common; \
      git clone --depth 1 --branch "${THEME_REF}" "${THEME_REPO}" theme_common; \
    else \
      echo "theme_common present -> using local copy"; \
    fi

# Install python deps (mkdocs/mike/plugins come from the theme)
RUN python -m pip install --upgrade pip \
 && pip install -r theme_common/requirements.txt

# (Optional) If you also have repo-specific python deps:
# RUN if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

# Merge theme resources + mkdocs config
RUN python theme_common/scripts/combine_theme_resources.py \
      -s theme_common/resources \
      -ov theme_override/resources \
      -o dist/_theme

RUN python theme_common/scripts/combine_mkdocs_config_yaml.py \
      theme_common/mkdocs.yml \
      theme_override/mkdocs.yml \
      mkdocs.yml

# Build static site into /home/1001/application/site
RUN mkdocs build

#################################
# Runtime: nginx serving the site
#################################
FROM nginxinc/nginx-unprivileged:1.28-alpine AS deploy

# Copy built site
COPY --from=builder /home/1001/application/site/ /usr/share/nginx/html/

# Nginx config
COPY default.conf /etc/nginx/conf.d/default.conf

USER 1001

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

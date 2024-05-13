# Copyright (c) Microsoft Corporation and others. Licensed under the MIT license.
# SPDX-License-Identifier: MIT

FROM node:18-bullseye
ENV APPDIR=/opt/service

ARG BUILD_NUMBER=0
ENV CRAWLER_BUILD_NUMBER=$BUILD_NUMBER

# Ruby and Python Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends --no-install-suggests curl bzip2 build-essential libssl-dev libreadline-dev zlib1g-dev cmake python3 python3-dev python3-pip xz-utils libxml2-dev libxslt1-dev libpopt0 && \
  rm -rf /var/lib/apt/lists/* && \
  curl -L https://github.com/rbenv/ruby-build/archive/v20180822.tar.gz | tar -zxvf - -C /tmp/ && \
  cd /tmp/ruby-build-* && ./install.sh && cd / && \
  ruby-build -v 2.5.1 /usr/local && rm -rfv /tmp/ruby-build-* && \
  gem install bundler -v 2.3.26 --no-document

# Scancode
ARG SCANCODE_VERSION="32.1.0"
RUN pip3 install --upgrade pip setuptools wheel && \
  curl -Os https://raw.githubusercontent.com/nexB/scancode-toolkit/v$SCANCODE_VERSION/requirements.txt && \
  pip3 install --constraint requirements.txt scancode-toolkit==$SCANCODE_VERSION && \
  rm requirements.txt && \
  scancode-reindex-licenses && \
  scancode --version

ENV SCANCODE_HOME=/usr/local/bin

# Licensee
# The latest version of nokogiri (1.13.1) and faraday (2.3.0) requires RubyGem 2.6.0 while
# the current RubyGem is 2.5.1. However, after upgrading RubyGem to 3.1.2, licensee:9.12.0 starts
# to have hard time to find license in LICENSE file, like component npm/npmjs/-/caniuse-lite/1.0.30001344.
# So we pin to the previous version of nokogiri and faraday.
RUN gem install nokogiri:1.12.5 --no-document && \
  gem install faraday:1.10.0 --no-document && \
  gem install public_suffix:4.0.7 --no-document && \
  gem install licensee:9.12.0 --no-document

# REUSE
RUN pip3 install setuptools
RUN pip3 install reuse==3.0.1

# Crawler config
ENV CRAWLER_DEADLETTER_PROVIDER=cd(azblob)
ENV CRAWLER_NAME=cdcrawlerprod
ENV CRAWLER_QUEUE_PREFIX=cdcrawlerprod
ENV CRAWLER_QUEUE_PROVIDER=storageQueue
ENV CRAWLER_STORE_PROVIDER=cdDispatch+cd(azblob)+azqueue
ENV CRAWLER_WEBHOOK_URL=https://api.clearlydefined.io/webhook
ENV CRAWLER_AZBLOB_CONTAINER_NAME=production

RUN git config --global --add safe.directory '*'

COPY package*.json /tmp/
COPY patches /tmp/patches
RUN cd /tmp && npm install --omit=dev
RUN mkdir -p "${APPDIR}" && cp -a /tmp/node_modules "${APPDIR}"

WORKDIR "${APPDIR}"
COPY . "${APPDIR}"

ENV PORT 5000
EXPOSE 5000
ENTRYPOINT ["node", "index.js"]

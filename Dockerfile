#
# Copyright (c) 2020-2021 IOTech Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ARG BASE=golang:1.18-alpine3.16
FROM ${BASE} AS builder

ARG ALPINE_PKG_BASE="make git openssh-client gcc libc-dev zeromq-dev libsodium-dev"
ARG ALPINE_PKG_EXTRA=""

# set the working directory
WORKDIR /device-virtual-go

# Replicate the APK repository override.
# If it is no longer necessary to avoid the CDN mirros we should consider dropping this as it is brittle.
RUN sed -e 's/dl-cdn[.]alpinelinux.org/dl-4.alpinelinux.org/g' -i~ /etc/apk/repositories
# Install our build time packages.
RUN apk add --update --no-cache ${ALPINE_PKG_BASE} ${ALPINE_PKG_EXTRA}

COPY go.mod vendor* ./
RUN [ ! -d "vendor" ] && go mod download all || echo "skipping..."

COPY . .
# To run tests in the build container:
#   docker build --build-arg 'MAKE=build test' .
# This is handy of you do your Docker business on a Mac
ARG MAKE='make build'
RUN $MAKE

FROM alpine:3.16

LABEL license='SPDX-License-Identifier: Apache-2.0' \
  copyright='Copyright (c) 2019-2021: IOTech'

RUN sed -e 's/dl-cdn[.]alpinelinux.org/dl-4.alpinelinux.org/g' -i~ /etc/apk/repositories
RUN apk add --update --no-cache zeromq dumb-init

WORKDIR /
COPY --from=builder /device-virtual-go/Attribution.txt /
COPY --from=builder /device-virtual-go/LICENSE /
COPY --from=builder /device-virtual-go/cmd /

EXPOSE 59900

ENTRYPOINT ["/device-virtual"]
CMD ["--cp=consul.http://edgex-core-consul:8500", "--registry", "--confdir=/res"]

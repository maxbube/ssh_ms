# vim: ts=8:sw=8:ft=make:noai:noet
SHELL=/bin/bash

BUILD_DIR?="./bin"
GO?="`which go`"
GOLINT?="`which golint`"
RELEASE_VER?="`git rev-parse HEAD`"

SSH_MS_BASEPATH?=~/.ssh/cache
SSH_MS_DEFAULT_VAULT_ADDR?=https://127.0.0.1:8200
SSH_MS_DEFAULT_USERNAME?="${USER}"
SSH_MS_USERNAME?=SSH_MS_USERNAME
SSH_MS_ID_FILE?=~/.ssh/id_rsa
SSH_MS_SYNC_HOST?=localhost
SSH_MS_SYNC_PATH?=/usr/share/nginx/html/downloads/ssh_ms/

DEBUG_BUILD=$(shell test "${DEBUG}" = "1" && echo 1 || echo 0)

PACKAGE=github.com/cezmunsta/ssh_ms
ifeq ($(DEBUG_BUILD), 1)
LDFLAGS=-ldflags "-X ${PACKAGE}/config.EnvBasePath=${SSH_MS_BASEPATH} -X ${PACKAGE}/cmd.Version=${RELEASE_VER} -X ${PACKAGE}/config.EnvSSHUsername=${SSH_MS_USERNAME} -X ${PACKAGE}/config.EnvSSHIdentityFile=${SSH_MS_ID_FILE} -X ${PACKAGE}/config.EnvSSHDefaultUsername=${SSH_MS_DEFAULT_USERNAME} -X ${PACKAGE}/config.EnvVaultAddr=${SSH_MS_DEFAULT_VAULT_ADDR}"
else
LDFLAGS=-ldflags "-w -X ${PACKAGE}/config.EnvBasePath=${SSH_MS_BASEPATH} -X ${PACKAGE}/cmd.Version=${RELEASE_VER} -X ${PACKAGE}/config.EnvSSHUsername=${SSH_MS_USERNAME} -X ${PACKAGE}/config.EnvSSHIdentityFile=${SSH_MS_ID_FILE} -X ${PACKAGE}/config.EnvSSHDefaultUsername=${SSH_MS_DEFAULT_USERNAME} -X ${PACKAGE}/config.EnvVaultAddr=${SSH_MS_DEFAULT_VAULT_ADDR}"
endif

all: lint format test binaries

binaries: binary-linux binary-mac

flags:
	@echo -e "\"${LDFLAGS}\"" | sed 's/-ldflags /-ldflags "/; s/^"//'

sync:
	@rsync -rlpDvc --progress bin/{linux,darwin} "${SSH_MS_SYNC_HOST}":"${SSH_MS_SYNC_PATH}"

binary-prep:
	@mkdir -p ${BUILD_DIR}/${GOOS}/${GOARCH};

binary-mac: export GOOS=darwin
binary-mac: export GOARCH=amd64
binary-mac: binary-prep
	@"${GO}" build -trimpath -o "${BUILD_DIR}/${GOOS}/${GOARCH}/ssh_ms" ${LDFLAGS};
	@xz -fkez9 "${BUILD_DIR}/${GOOS}/${GOARCH}/ssh_ms";

binary-linux: export GOOS=linux
binary-linux: export GOARCH=amd64
binary-linux: binary-prep
	@"${GO}" build -race -trimpath -o "${BUILD_DIR}/${GOOS}/${GOARCH}/ssh_ms" ${LDFLAGS};
	@xz -fkez9 "${BUILD_DIR}/${GOOS}/${GOARCH}/ssh_ms";

build: binary-prep
ifeq ($(DEBUG_BUILD), 1)
	@"${GO}" build -o "${BUILD_DIR}/ssh_ms.debug" ${LDFLAGS}
else
	@"${GO}" build -race -trimpath -o "${BUILD_DIR}/ssh_ms" ${LDFLAGS}
endif

dev-vault:
	@${SHELL} scripts/dev-vault.sh

test:
	@"${GO}" test "${PACKAGE}/ssh" "${PACKAGE}/cmd" "${PACKAGE}/vault" "${PACKAGE}/log" "${PACKAGE}/config"

mod-updates:
	@"${GO}" list -m -u all > updates.log
	@cat updates.log

lint:
	@"${GOLINT}" -set_exit_status "${PACKAGE}/ssh" "${PACKAGE}/cmd" "${PACKAGE}/vault" "${PACKAGE}/log" "${PACKAGE}/config"

format: export PACKAGE=./
format:
	@gofmt -w "${PACKAGE}/ssh" "${PACKAGE}/cmd" "${PACKAGE}/vault" "${PACKAGE}/log" "${PACKAGE}/config"

simplify: export PACKAGE=./
simplify:
	@gofmt -s -w "${PACKAGE}/ssh" "${PACKAGE}/cmd" "${PACKAGE}/vault" "${PACKAGE}/log" "${PACKAGE}/config"

vet:
	@"${GO}" vet "${PACKAGE}/ssh" "${PACKAGE}/cmd" "${PACKAGE}/vault"

fix: export PACKAGE=./
fix:
	@"${GO}" tool fix -diff "${PACKAGE}/ssh" "${PACKAGE}/cmd" "${PACKAGE}/vault" "${PACKAGE}/log" "${PACKAGE}/config"

clean:
	@find "${BUILD_DIR}" -type f -delete;
	@"${GO}" clean -x
	@"${GO}" clean -x -cache
	@"${GO}" clean -x -testcache

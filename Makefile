ASSETS := $(shell yq e '.assets.[].src' manifest.yaml)
ASSET_PATHS := $(addprefix assets/,$(ASSETS))
VERSION_TAG := $(shell git --git-dir=lnd/.git describe --abbrev=0)
VERSION := $(VERSION_TAG:v%=%)
VERSION_SIMPLE := $(shell echo $(VERSION) | sed -E 's/([0-9]+\.[0-9]+\.[0-9]+).*/\1/g')
LND_GIT_REF := $(shell cat .git/modules/lnd/HEAD)
LND_GIT_FILE := $(addprefix .git/modules/lnd/,$(if $(filter ref:%,$(LND_GIT_REF)),$(lastword $(LND_GIT_REF)),HEAD))
CONFIGURATOR_SRC := $(shell find ./configurator/src) configurator/Cargo.toml configurator/Cargo.lock

.DELETE_ON_ERROR:

all: lnd.s9pk

install: lnd.s9pk
	appmgr install lnd.s9pk

lnd.s9pk: manifest.yaml config_spec.yaml config_rules.yaml image.tar instructions.md $(ASSET_PATHS)
	appmgr -vv pack $(shell pwd) -o lnd.s9pk
	appmgr -vv verify lnd.s9pk

image.tar: Dockerfile docker_entrypoint.sh configurator/target/armv7-unknown-linux-musleabihf/release/configurator $(LND_GIT_FILE)
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --tag start9/lnd --platform=linux/arm/v7 -o type=docker,dest=image.tar .

configurator/target/armv7-unknown-linux-musleabihf/release/configurator: $(CONFIGURATOR_SRC)
	docker run --rm -it -v ~/.cargo/registry:/root/.cargo/registry -v "$(shell pwd)"/configurator:/home/rust/src start9/rust-musl-cross:armv7-musleabihf cargo +beta build --release
	docker run --rm -it -v ~/.cargo/registry:/root/.cargo/registry -v "$(shell pwd)"/configurator:/home/rust/src start9/rust-musl-cross:armv7-musleabihf musl-strip target/armv7-unknown-linux-musleabihf/release/configurator

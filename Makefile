.POSIX:

MIX_ENV ?= dev
VERSION ?= $(shell  grep -r version mix.exs | cut -d'"' -f2)

DOCKER_PROJECT ?= mediaverseeu
DOCKER_IMAGE ?= fader360-backend
# ?= defers variable resolution in recipes. need to pin it statically here
DOCKER_TAG := $(shell date +%Y%m%d-%H%M%S).v${VERSION}-${MIX_ENV}
DOCKER_LOCAL_IMAGE ?= "${DOCKER_IMAGE}:${DOCKER_TAG}"

all: help

.PHONY: proxy
proxy: ## start local development reverse proxy
	node assets/httpAndWebsocketProxy.js

.PHONY: deps
deps: ## initialize dependencies
	HEX_HTTP_TIMEOUT=120 mix do deps.get, deps.compile

.PHONY: init-web-assets
init-web-assets: ## initialize web assets
	yarn --cwd ./assets install --frozen-lockfile

.PHONY: init
init: | deps init-web-assets
init: ## initialize configurations and dependencies
	mix ua_inspector.download --force
	mix compile

.PHONY: refresh-db
refresh-db: ## re-initialize database
	mix do ecto.drop, ecto.create, ecto.migrate
	mix run priv/repo/seeds.exs

.PHONY: run
run: ## run local development server
	iex -S mix phx.server

.PHONY: test
test: ## run integration test suite
	mix test

.PHONY: check-lint
check-lint: | check-lint-elixir check-lint-js check-lint-html
check-lint: ## check all linting targets

.PHONY: check-lint-elixir
check-lint-elixir: ## check linting of elixir related files
	mix format --check-formatted

.PHONY: check-lint-js
check-lint-js: ## check linting of js/css related files
	yarn --cwd ./assets eslint --max-warnings 0 --ignore-pattern '!.eslintrc.js' .eslintrc.js
	yarn --cwd ./assets eslint --max-warnings 0 --ignore-pattern '!.prettierrc.js' .prettierrc.js
	yarn --cwd ./assets eslint --max-warnings 0 *.js js
	yarn --cwd ./assets prettier --check .

.PHONY: check-lint-html
check-lint-html: ## check linting of html and html template related files
	$(MAKE) lint-html
	git diff-index HEAD

.PHONY: lint
lint: ## perform linting with automatic fixes on all files
	mix format
	yarn --cwd ./assets eslint --fix --ignore-pattern '!.eslintrc.js' .eslintrc.js
	yarn --cwd ./assets eslint --fix --ignore-pattern '!.prettierrc.js' .prettierrc.js
	yarn --cwd ./assets eslint --fix *.js js
	yarn --cwd ./assets prettier --write .

.PHONY: lint-html
lint-html: ## lint html templates
	find lib -name "*.html.eex" -or -name "*.html.leex" -or -name "*.html.heex" | \
		xargs ./assets/node_modules/.bin/js-beautify --type html -r -f

.PHONY: clean
clean : ## delete build artifacts
	rm -rf \
		_build \
		assets/node_modules \
		deps \
		doc \
		priv/static/assets \
		priv/static/cache_manifest.json

.PHONY: dockerhub-login
dockerhub-login: ## loginto mediaversue docker hub
	docker login

.PHONY: docker-tag
docker-tag: ## tag local docker image
	test -n "$(DOCKER_LOCAL_IMAGE)"  # $$DOCKER_LOCAL_IMAGE
	docker tag ${DOCKER_LOCAL_IMAGE} ${DOCKER_PROJECT}/${DOCKER_IMAGE}:${DOCKER_TAG}

.PHONY: docker-push
docker-push: ## push local tagged docker image to repository
	docker push ${DOCKER_PROJECT}/${DOCKER_IMAGE}:${DOCKER_TAG}

.PHONY: docker-list
docker-list: ## list docker images in repository
	docker image ls --all ${DOCKER_PROJECT}/${DOCKER_IMAGE}

.PHONY: docker-pull
docker-pull: ## pull docker image from repository
	docker pull ${DOCKER_PROJECT}/${DOCKER_IMAGE}:${DOCKER_TAG}

.PHONY: docker-build
docker-build: ## build docker based image for distribution
	rsync --verbose --human-readable --progress --archive --compress --delete \
		Makefile config lib assets priv mix.exs mix.lock docker/work/
	MIX_ENV=${MIX_ENV} \
	DOCKER_IMAGE=${DOCKER_IMAGE} \
	DOCKER_TAG=${DOCKER_TAG} \
	VERSION=${VERSION} \
	docker compose build fader360_backend

.PHONY: build-upload-release
build-upload-release: | docker-build docker-tag docker-push
build-upload-release: ## build, tag and push a new release docker image

.PHONY: docker-dev
docker-dev: ## run local docker container in interactive iex mode
	rsync --verbose --human-readable --progress --archive --compress --delete \
		Makefile config lib assets priv mix.exs mix.lock docker/work/
	MIX_ENV=${MIX_ENV} \
	DOCKER_IMAGE=${DOCKER_IMAGE} \
	DOCKER_TAG=${DOCKER_TAG} \
	VERSION=${VERSION} \
	docker compose run --service-ports darth_dev

.PHONY: docker-refresh-db
docker-refresh-db: ## run local docker container to refresh database
	rsync --verbose --human-readable --progress --archive --compress --delete \
		Makefile config lib assets priv mix.exs mix.lock docker/work/
	MIX_ENV=${MIX_ENV} \
	DOCKER_IMAGE=${DOCKER_IMAGE} \
	DOCKER_TAG=${DOCKER_TAG} \
	VERSION=${VERSION} \
	docker compose up darth_refresh_db

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

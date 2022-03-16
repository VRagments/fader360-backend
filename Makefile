.POSIX:

all: help

.PHONY: VERSION
VERSION:
	git describe --dirty --abbrev=7 --tags --always --first-parent > VERSION


.PHONY: deps
deps: ## initialize dependencies
	HEX_HTTP_TIMEOUT=120 mix do deps.get, deps.compile


.PHONY: init
init: | deps
init: ## initialize configurations and dependencies
	mix compile


.PHONY: refresh-db
refresh-db: ## re-initialize database
	mix do ecto.drop, ecto.create, ecto.migrate
	mix run priv/repo/seeds.exs


.PHONY: run
run: ## run local development server
	iex -S mix phx.server


.PHONY: clean
clean : ## delete build artifacts
	rm -rf \
		_build \
		assets/node_modules \
		deps \
		doc \
		priv/static/assets \
		priv/static/cache_manifest.json


.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

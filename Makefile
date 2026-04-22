PORT ?= 4017
BIND ?= 0.0.0.0

.PHONY: install frontend build start clean website-install website-frontend website-build website-start

install:
	bundle install
	npm install

frontend:
	bundle exec rake frontend:build

build: frontend
	bundle exec bridgetown build

start:
	bundle exec bridgetown start -P $(PORT) -B $(BIND)

clean:
	bundle exec bridgetown clean

website-install: install

website-frontend: frontend

website-build: build

website-start: start

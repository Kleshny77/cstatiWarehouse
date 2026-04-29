SHELL := /bin/bash

ENV_FILE ?= .env
include $(ENV_FILE)
export

.PHONY: help tidy run test test-integration vet up up-all down logs psql migrate-up migrate-down migrate-status docker-build docker-up docker-down docker-logs seed-warehouse seed-cstati-party reset-dev-data

help:
	@echo "make up             — поднять только Postgres в docker-compose"
	@echo "make up-all         — поднять Postgres + backend"
	@echo "make down           — остановить всё"
	@echo "make logs           — логи Postgres"
	@echo "make psql           — psql-консоль в контейнере"
	@echo "make migrate-up     — применить миграции"
	@echo "make migrate-down   — откатить одну миграцию"
	@echo "make migrate-status — статус миграций"
	@echo "make run            — запустить backend локально (без docker)"
	@echo "make test           — unit-тесты"
	@echo "make test-integration — integration-тесты (требуется поднятый Postgres)"
	@echo "make docker-build   — пересобрать образ backend"
	@echo "make docker-up      — поднять backend+postgres через docker compose up --build"
	@echo "make docker-logs    — логи backend"
	@echo "make seed-warehouse — залить тестовые позиции склада в личную организацию samsonovartem00@gmail.com"
	@echo "make seed-cstati-party — залить позиции в организацию «cstati» (samsonovartem00@gmail.com)"
	@echo "make reset-dev-data — удалить всех пользователей и связанные данные (dev, схему не трогает)"
	@echo "make vet            — go vet ./..."
	@echo "make tidy           — go mod tidy"

tidy:
	go mod tidy

run:
	go run ./cmd/server

test:
	go test ./...

test-integration:
	go test -tags=integration -count=1 ./...

vet:
	go vet ./...

up:
	docker compose up -d postgres

up-all:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f postgres

psql:
	docker compose exec postgres psql -U cstati -d cstatiwarehouse

migrate-up:
	go run ./cmd/migrate up

migrate-down:
	go run ./cmd/migrate down

migrate-status:
	go run ./cmd/migrate status

docker-build:
	docker compose build backend

docker-up:
	docker compose up -d --build

docker-logs:
	docker compose logs -f backend

seed-warehouse:
	cat scripts/seed_dev_warehouse.sql | docker compose exec -T postgres psql -U cstati -d cstatiwarehouse

seed-cstati-party:
	cat scripts/seed_cstati_org_party.sql | docker compose exec -T postgres psql -U cstati -d cstatiwarehouse

reset-dev-data:
	@if command -v psql >/dev/null 2>&1; then \
		psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f scripts/dev_reset_data.sql; \
	else \
		cat scripts/dev_reset_data.sql | docker compose exec -T postgres psql -U cstati -d cstatiwarehouse; \
	fi

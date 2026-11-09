# команды проекта, запускаются из папки dbt/
# на Windows make можно взять из Git Bash, WSL или scoop, команды внутри обычные dbt/sqlfluff/pre-commit

DBT ?= dbt
PYTHON ?= python
CSV ?= data/train.csv
PORT ?= 8080

.DEFAULT_GOAL := help
.PHONY: help install clickhouse-up clickhouse-down load-data debug deps seed run test data-test unit-test \
        build docs docs-serve lint fix pre-commit-install pre-commit all clean

help: ## список команд
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'

install: ## поставить dbt-core, dbt-clickhouse, sqlfluff и pre-commit
	$(PYTHON) -m pip install -r requirements.txt

clickhouse-up: ## поднять ClickHouse в Docker
	docker compose up -d --wait

clickhouse-down: ## остановить ClickHouse
	docker compose down

load-data: ## создать transactions_db.transactions и загрузить CSV, путь задаётся через CSV=...
	$(PYTHON) scripts/load_transactions.py --csv $(CSV) --recreate

debug: ## проверить подключение к ClickHouse
	$(DBT) debug

deps: ## поставить пакеты dbt_utils, dbt_date, dbt_expectations
	$(DBT) deps

seed: ## загрузить справочник штатов
	$(DBT) seed

run: ## построить staging, intermediate и витрины
	$(DBT) run

test: ## все тесты: generic, singular и unit
	$(DBT) test

data-test: ## только тесты данных (generic и singular)
	$(DBT) test --select "test_type:data"

unit-test: ## только unit-тесты
	$(DBT) test --select "test_type:unit"

build: ## seed, run и test в порядке графа зависимостей
	$(DBT) build

docs: ## сгенерировать документацию в target/
	$(DBT) docs generate

docs-serve: docs ## открыть документацию на http://localhost:$(PORT)
	$(DBT) docs serve --port $(PORT)

lint: ## проверить SQL через sqlfluff
	sqlfluff lint models tests

fix: ## автоисправление SQL через sqlfluff
	sqlfluff fix models tests

pre-commit-install: ## поставить git-хуки из .pre-commit-config.yaml
	pre-commit install --config .pre-commit-config.yaml

pre-commit: ## прогнать все хуки по всем файлам
	pre-commit run --config .pre-commit-config.yaml --all-files

all: deps seed run test ## полный цикл из задания

clean: ## удалить target/ и dbt_packages/
	$(DBT) clean

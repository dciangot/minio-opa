all: install

install:
	mkdir -p data
	docker-compose up -d

start:
	docker-compose up -d

stop:
	docker-compose down

DOCBIN?=mkdocs

all: publish-doc

install:
	mkdir -p data
	docker-compose up -d

start:
	docker-compose up -d

stop:
	docker-compose down

publish-doc:
	cp README.md docs/README.md
	${DOCBIN} gh-deploy
build:
	stack exec engine -- build

watch:
	stack exec engine -- watch

check:
	stack exec engine -- check

rebuild:
	rm -rf _site _cache
	make build

build-engine:
	stack build

deploy:
	rm deploy.zip; zip -r deploy _site/*
	curl -H "Content-Type: application/zip" \
     -H "Authorization: Bearer 2585fb207cee3c20d62c7472c76773654fb4b2942e4a5c6446945078eafa7b99" \
     --data-binary "@deploy.zip" \
     https://api.netlify.com/api/v1/sites/kerestey-net.netlify.com/deploys
	rm deploy.zip
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
	curl -f \
	  -H "Content-Type: application/zip" \
	  -H "Authorization: Bearer ${NETLIFY_TOKEN}" \
	  --data-binary "@deploy.zip" \
	  https://api.netlify.com/api/v1/sites/kerestey-net.netlify.com/deploys
	rm deploy.zip
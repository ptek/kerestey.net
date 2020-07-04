engine=$(shell find .stack-work/dist/x86_64-osx -type f -name 'engine' | sort | head -1)

build:
	$(engine) build

watch:
	$(engine) watch

check:
	$(engine) check

rebuild:
	rm -rf _site _cache
	make build

build-engine:
	stack build

deploy:
	rm -f deploy.zip; zip -r deploy _site/*
	@set -o pipefail; \
		curl -f \
		  -H "Content-Type: application/zip" \
		  -H "Authorization: Bearer ${NETLIFY_TOKEN}" \
		  --data-binary "@deploy.zip" \
		  https://api.netlify.com/api/v1/sites/kerestey-net.netlify.com/deploys | grep '.' | jq -er '.deploy_ssl_url'
	rm deploy.zip
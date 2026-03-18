bootstrap:
	./scripts/bootstrap.sh

up:
	COMPOSE_FILE=docker-compose.yml:docker-compose.traefik.yml ./vendor/bin/sail up -d laravel.test

wt-create:
	./scripts/worktree-create.sh "$(BRANCH)"

wt-clean:
	./scripts/worktree-cleanup.sh

traefik-ensure:
	./scripts/traefik.sh ensure

traefik-prune:
	./scripts/traefik.sh prune

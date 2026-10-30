bootstrap:
	./scripts/bootstrap.sh

status:
	./scripts/status.sh

up:
	docker compose --file docker-compose.yml --file docker-compose.traefik.yml up -d app vite

wt-create:
	./scripts/worktree-create.sh "$(BRANCH)"

wt-clean:
	./scripts/worktree-cleanup.sh

traefik-ensure:
	./scripts/traefik.sh ensure

traefik-prune:
	./scripts/traefik.sh prune

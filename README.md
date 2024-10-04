# phoenix-photo-tagger

## Steps taken to set up project initially
1. Initially, only the docker-compose.yml and Dockerfile exist.
2. Run `docker-compose run --build app bash` to build the image, run the container, and open a bash shell in the container.
3. Run `mix phx.new . --app phoenix_photo_tagger --no-live` to create a new Phoenix project.
4. Edit database hostname and http ip in config/dev.exs to get working in docker container.
5. Run `mix ecto.create` to setup connection to database.
6. Run `mix local.hex --force` to initialize package manager.
7. Exit the docker container, and run `sudo chown -R $USER:$USER ./app` to change ownership of the files by scripts run in docker (which runs as root by default). This allows saving the files in vscode.
8. To run further mix commands in server (like ecto cmds), run `docker-compose run --user $(id -u):$(id -g) app bash`.


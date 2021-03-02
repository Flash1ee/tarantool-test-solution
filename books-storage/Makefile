docker_name := books_db
docker_tag  := latest
container_name := books-storage
run_flags := --rm -it -d

PORT := 8081

docker:
	sudo docker build -t ${docker_name}:${docker_tag} .
	
run:
	sudo docker run ${run_flags} --name ${container_name} \
		-p ${PORT}:8081 \
		-e PORT=8081 \
		--net=host \
        ${docker_name}:${docker_tag}

stop:
	sudo docker stop ${container_name}

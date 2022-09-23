docker stop talkback-janus
docker rm talkback-janus
docker run -d --restart unless-stopped --name talkback-janus --network=host -it talkback-janus-image-linux:latest

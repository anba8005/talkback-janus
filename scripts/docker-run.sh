docker stop talkback-janus
docker run -d --name talkback-janus --network=host --rm -it talkback-janus-image-linux:latest

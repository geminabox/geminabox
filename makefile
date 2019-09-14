IMAGE=registry.magz.xyz:5000/geminabox:0.0.1

build:
	docker build -t $(IMAGE) .

brun: build
	docker run --rm -ti -v "$(shell pwd):/usr/src/app" -v "$(shell pwd)/data:/geminabox/data" -e RUBYGEMS_PROXY=true -p 9292:9292 $(IMAGE)

run:
	docker run --rm -ti -v "$(shell pwd):/usr/src/app" -v "$(shell pwd)/data:/geminabox/data" -e RUBYGEMS_PROXY=true -p 9292:9292 $(IMAGE)		
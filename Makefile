all: build
test: run

bootstrap:
	bundle install

build:
	bundle exec jekyll build

run:
	bundle exec jekyll serve -V --watch --baseurl '' -c _config.yml,_config_local.yml

clean:
	/bin/rm -rf _site/*

pub: build
	cp -rv _site/* ../amin.bitbucket.org/

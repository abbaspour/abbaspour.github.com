all: build
test: run

bootstrap:
	bundle install

build:
	bundle exec jekyll build

run:
	jekyll server -V --watch --baseurl ''

clean:
	/bin/rm -rf _site/*

pub: build
	cp -rv _site/* ../amin.bitbucket.org/

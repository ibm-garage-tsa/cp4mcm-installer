.PHONY: all
all: install post

.PHONY: install
install:
	./cp4m/cp4mcm-install.sh

.PHONY: post
post:
	./cp4m/cp4mcm-post-install.sh

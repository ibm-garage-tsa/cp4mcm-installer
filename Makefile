all: mcmcore
.PHONY: all

mcmcore:
	./cp4m/cp4mcm-install.sh
	./cp4m/cp4mcm-post-install.sh
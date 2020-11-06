.PHONY: all
all: end_to_end

.PHONY: end_to_end
end_to_end:
	./cp4m/cp4mcm-install.sh
	./cp4m/cp4mcm-post-install.sh

.PHONY: install
install:
	./cp4m/cp4mcm-install.sh

.PHONY: post
post:
	./cp4m/cp4mcm-post-install.sh

all: mcmcore mcmenablemonitoring mcmenableim
.PHONY: all

mcmcore:
	./1-common-services.sh
	./cp4m/2-cp4mcm-core.sh

mcmenablemonitoring:
	./cp4m/6-MonitoringModule.sh

mcmenableim:
	./cp4m/3-ldap.sh
	./cp4m/4-CAMandIM.sh
	./cp4m/5-CloudFormsandOIDC.sh
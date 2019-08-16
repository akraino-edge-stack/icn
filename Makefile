SHELL:=/bin/bash
BMDIR:=$(CURDIR)/env/metal3
METAL3DIR:=$(CURDIR)/deploy/metal3/scripts
all: bm_install

bm_preinstall:
	pushd $(BMDIR) && ./01_install_package.sh && ./02_configure.sh && ./03_launch_prereq.sh && popd

bm_install:
	pushd $(METAL3DIR) && ./metal3.sh && popd 

.PHONY: all bm_preinstall bm_install

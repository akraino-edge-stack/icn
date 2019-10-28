all: bmh_install bmh_configure bmh_launch bmh_verify

bmh: bmh_configure bmh_launch bmh_verify

bmh_install:
	./01_install_requirements.sh

bmh_configure:
	./02_configure_host.sh

bmh_launch:
	./03_launch_mgmt_cluster.sh

bmh_verify:
	./04_verify.sh

bmh_clean:
	./05_host_cleanup.sh

.PHONY: all bmh bmh_install bmh_configure bmh_launch bmh_verify bmh_clean

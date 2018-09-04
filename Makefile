
base:
	packer build base/packer.json

controller:
	packer build controller/packer.json

bastion:
	packer build bastion/packer.json

.PHONY: base controller bastion
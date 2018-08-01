
base: base/packer.json
	packer build base/packer.json

controller: controller/packer.json base/packer.json
	packer build controller/packer.json

bastion: bastion/packer.json base/packer.json
	packer build bastion/packer.json

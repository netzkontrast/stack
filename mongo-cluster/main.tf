/**
setup mongo db cluster
*/

variable "replicaset_name" {
  description = "name of the replicaset"
  default = "rs1"
}

variable "instance_count" {
  description = "how many mongo nodes (min. 2 - and an arbiter is installed no matter what)"
  default = 2
}

variable "instance_type" {
  description = "tpye of the ec2 instance"
  default = "r4.large"
}

variable "disk_size" {
  description = "the size of the data-disk"
  default = 1000
}

variable "region" {
  description = "the aws region"
  default = "eu-central-1"
}

variable "security_groups" {
  description = "a comma separated lists of security group IDs"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "key_name" {
  description = "The SSH key pair, key name"
}

variable "subnet_id" {
  description = "A external subnet id"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "private_key_file" {
  description = "the path to the private key file"
}

variable "dns_name" {
  description = "The subdomain under which the host is exposed internaly, defaults to bastion"
  default = "mongo"
}

variable "zone_id" {
  description = "Route53 zone ID to use for dns_name"
}



module "ami" {
  source        = "github.com/terraform-community-modules/tf_aws_ubuntu_ami/ebs"
  region        = "${var.region}"
  distribution  = "trusty"
  instance_type = "${var.instance_type}"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user-data.sh")}"
  vars {
    mongodb_version          = "${var.mongodb_version}"
    mongodb_basedir          = "${var.mongodb_basedir}"
    mongodb_conf_logpath     = "${var.mongodb_conf_logpath}"
    mongodb_conf_engine      = "${var.mongodb_conf_engine}"
    mongodb_conf_replsetname = "${var.mongodb_conf_replsetname}"
    mongodb_conf_oplogsizemb = "${var.mongodb_conf_oplogsizemb}"
    mongodb_key_s3_object    = "${var.mongodb_key_s3_object}"
    ssl_ca_key_s3_object     = "${var.ssl_ca_key_s3_object}"
    ssl_mongod_key_s3_object = "${var.ssl_mongod_key_s3_object}"
    ssl_agent_key_s3_object  = "${var.ssl_agent_key_s3_object}"
    opsmanager_key_s3_object = "${var.opsmanager_key_s3_object}"
    opsmanager_subdomain     = "${var.opsmanager_subdomain}"
    hostname                 = "${var.route53_hostname}"
    aws_region               = "${var.aws_region}"
    config_ephemeral         = "${var.config_ephemeral}"
    config_ebs               = "${var.config_ebs}"
    role_node                = "${var.role_node}"
    role_opsmanager          = "${var.role_opsmanager}"
    role_backup              = "${var.role_backup}"
    mms_group_id             = "${var.mms_group_id}"
    mms_api_key              = "${var.mms_api_key}"
    mms_password             = "${var.mms_password}"
  }
}


resource "aws_instance" "mongo" {
  count                  = "${instance_count}"
  ami                    = "${module.ami.ami_id}"
  source_dest_check      = false
  instance_type          = "${var.instance_type}"
  subnet_id              = "${var.subnet_id}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${split(",",var.security_groups)}"]
  monitoring             = true
  user_data              = "${file(format("%s/user_data.sh", path.module))}"

  tags {
    Name        = "mongo"
    Environment = "${var.environment}"
  }

  root_block_device {
    volume_size = 64
    volume_type = "gp2"
    delete_on_termination = true
  }

  provisioner "file" {
    source      = "${format("%s/provision.sh", path.module)}"
    destination = "/tmp/provision.sh"
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file(var.private_key_file)}"
    }
  }

  provisioner "file" {
    source      = "${var.private_key_file}"
    destination = "/home/ubuntu/.ssh/id_rsa"
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file(var.private_key_file)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ubuntu/.ssh/id_rsa",
    ]
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file(var.private_key_file)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/provision.sh",
      "/tmp/provision.sh",
    ]
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file(var.private_key_file)}"
    }
  }


}

resource "aws_eip" "bastion" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true
}

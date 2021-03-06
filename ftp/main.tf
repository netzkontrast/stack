/**
 * The bastion host acts as the "jump point" for the rest of the infrastructure.
 * Since most of our instances aren't exposed to the external internet, the bastion acts as the gatekeeper for any direct SSH access.
 * The bastion is provisioned using the key name that you pass to the stack (and hopefully have stored somewhere).
 * If you ever need to access an instance directly, you can do it by "jumping through" the bastion.
 *
 *    $ terraform output # print the bastion ip
 *    $ ssh -i <path/to/key> ubuntu@<bastion-ip> ssh ubuntu@<internal-ip>
 *
 * Usage:
 *
 *    module "bastion" {
 *      source            = "github.com/segmentio/stack/bastion"
 *      region            = "us-west-2"
 *      security_groups   = "sg-1,sg-2"
 *      vpc_id            = "vpc-12"
 *      key_name          = "ssh-key"
 *      subnet_id         = "pub-1"
 *      environment       = "prod"
 *    }
 *
 */

variable "instance_type" {
  default     = "t2.micro"
  description = "Instance type, see a list at: https://aws.amazon.com/ec2/instance-types/"
}

variable "region" {
  description = "AWS Region, e.g us-west-2"
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
  description = "The subdomain under which the host is exposed externally, defaults to ftp"
  default = "ftp"
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

resource "aws_instance" "ftp" {
  ami                    = "${module.ami.ami_id}"
  source_dest_check      = false
  instance_type          = "${var.instance_type}"
  subnet_id              = "${var.subnet_id}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${split(",",var.security_groups)}"]
  monitoring             = true
  user_data              = "${file(format("%s/user_data.sh", path.module))}"

  tags {
    Name        = "bastion"
    Environment = "${var.environment}"
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


resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${var.dns_name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_eip.bastion.public_ip}"]
}


// Bastion external IP address.
output "external_ip" {
  value = "${aws_eip.bastion.public_ip}"
}

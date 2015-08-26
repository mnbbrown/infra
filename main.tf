provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
}

provider "cloudflare" {
    email = "${var.cloudflare_email}"
    token = "${var.cloudflare_token}"
}

resource "aws_vpc" "coreosvpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
}

resource "aws_internet_gateway" "coreosig" {
    vpc_id = "${aws_vpc.coreosvpc.id}"
}

resource "aws_subnet" "coreossubneta" {
    vpc_id = "${aws_vpc.coreosvpc.id}"

    cidr_block = "10.0.0.0/24"
    availability_zone = "${var.region}a"
}

resource "aws_subnet" "coreossubnetb" {
    vpc_id = "${aws_vpc.coreosvpc.id}"

    cidr_block = "10.0.2.0/24"
    availability_zone = "${var.region}b"
}


resource "aws_route_table" "coreospublicrt" {
    vpc_id = "${aws_vpc.coreosvpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.coreosig.id}"
    }
}

resource "aws_route_table_association" "coreossubnetart" {
    subnet_id = "${aws_subnet.coreossubneta.id}"
    route_table_id = "${aws_route_table.coreospublicrt.id}"
}

resource "aws_route_table_association" "coreossubnetbrt" {
    subnet_id = "${aws_subnet.coreossubnetb.id}"
    route_table_id = "${aws_route_table.coreospublicrt.id}"
}

resource "aws_security_group" "coreossg" {
    name = "coreos-sg"
    description = "CoreOS Cluster Security Group"
    vpc_id ="${aws_vpc.coreosvpc.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = ["${aws_security_group.bastionhosts.id}"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_security_group" "bastionhosts" {
    name = "bastionhosts"
    description = "Bastion Host Security Group"
    vpc_id = "${aws_vpc.coreosvpc.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 62201
        to_port = 62201
        protocol = "udp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "coreossgself" {
    name = "coreos-sg-self"
    description = "CoreOS Cluster Security Group"
    vpc_id ="${aws_vpc.coreosvpc.id}"

    ingress {
        from_port = 4001
        to_port = 4001
        protocol = "tcp"
        security_groups = ["${aws_security_group.coreossg.id}"]
    }

    ingress {
        from_port = 7001
        to_port = 7001
        protocol = "tcp"
        security_groups = ["${aws_security_group.coreossg.id}"]
    }

    ingress {
        from_port = 8301
        to_port = 8301
        protocol = "tcp"
        security_groups = ["${aws_security_group.coreossg.id}"]
    }

    ingress {
        from_port = 8300
        to_port = 8300
        protocol = "tcp"
        security_groups = ["${aws_security_group.coreossg.id}"]
    }

    ingress {
        from_port = 8302
        to_port = 8302
        protocol = "tcp"
        security_groups = ["${aws_security_group.coreossg.id}"]
    }

}

resource "aws_instance" "bastion" {
    ami = "${lookup(var.ubuntu_amis, var.region)}"
    availability_zone = "${var.region}a"
    instance_type = "${var.bastion_instance_size}"
    security_groups = ["${aws_security_group.bastionhosts.id}"]
    associate_public_ip_address = true
    subnet_id = "${aws_subnet.coreossubneta.id}"
    key_name = "${var.key_name}"
    tags {
        Name = "bastionhosts"
    }
}

resource "aws_instance" "coreos" {
    ami = "${lookup(var.coreos_amis, var.region)}"
    availability_zone = "${var.region}a"
    instance_type = "${var.instance_size}"
    security_groups = [
        "${aws_security_group.coreossg.id}"
        , "${aws_security_group.coreossgself.id}"
    ]
    count = "${var.cluster_size}"
    associate_public_ip_address = true
    subnet_id = "${aws_subnet.coreossubneta.id}"
    user_data = "${file(\"cloud-config.yaml\")}"
    key_name = "${var.key_name}"
    tags {
        Name = "coreos-${count.index}"
    }
}


resource "aws_route53_zone" "coreos_zone" {
  name = "c.mbgo.co"
  vpc_id = "${aws_vpc.coreosvpc.id}"

  tags {
    Environment = "coreos"
  }
}

resource "aws_route53_record" "coreos_records" {
   depends_on = ["aws_route53_zone.coreos_zone"]
   zone_id = "${aws_route53_zone.coreos_zone.zone_id}"
   name = "coreos-${count.index}"
   count = "${var.cluster_size}"
   type = "A"
   ttl = "10"
   records = ["${element(aws_instance.coreos.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "bastion_record" {
   depends_on = ["aws_route53_zone.coreos_zone"]
   zone_id = "${aws_route53_zone.coreos_zone.zone_id}"
   name = "bastion"
   type = "A"
   ttl = "10"
   records = ["${aws_instance.bastion.private_ip}"]
}

output "bastion" {
    value = "${aws_instance.bastion.public_dns}"
}

# output "coreos_public_ip_addresses" {
#   value = "\n    ${join("\n    ", aws_instance.coreos.*.public_ip)}"
# }


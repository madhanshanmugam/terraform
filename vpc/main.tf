
provider "aws" {
  region = "${var.region}"
}

resource "aws_vpc" "myvpc" {
  cidr_block           = "${var.cidr}"
  tags                 = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

resource "aws_internet_gateway" "myvpc" {
  vpc_id = "${aws_vpc.myvpc.id}"
  tags   = "${merge(var.tags, map("Name", format("%s-igw", var.name)))}"
}

resource "aws_subnet" "nat_subnet" {
  vpc_id            = "${aws_vpc.myvpc.id}"
  cidr_block        = "${var.nat_subnet[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.nat_subnet)}"
  tags              = "${merge(var.tags, map("Name", format("%s_NAT_SUBNET_%d",var.name_space , count.index)))}"
}

resource "aws_subnet" "ssh_subnet" {
  vpc_id            = "${aws_vpc.myvpc.id}"
  cidr_block        = "${var.ssh_subnet[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.ssh_subnet)}"
  tags              = "${merge(var.tags, map("Name", format("%s_SSH_SUBNET_%d",var.name_space , count.index)))}"
}

resource "aws_subnet" "db_subnet" {
  vpc_id            = "${aws_vpc.myvpc.id}"
  cidr_block        = "${var.db_subnet[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.db_subnet)}"
  tags              = "${merge(var.tags, map("Name", format("%s_DB_SUBNET_%d",var.name_space , count.index)))}"
}

resource "aws_subnet" "public_elb_subnet" {
  vpc_id            = "${aws_vpc.myvpc.id}"
  cidr_block        = "${var.public_elb_subnet[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.public_elb_subnet)}"
  tags              = "${merge(var.tags, map("Name", format("%s_PUBLIC_ELB_SUBNET_%d",var.name_space , count.index)))}"
}


resource "aws_subnet" "app_subnet" {
  vpc_id            = "${aws_vpc.myvpc.id}"
  cidr_block        = "${var.app_subnet[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.app_subnet)}"
  tags              = "${merge(var.tags, map("Name", format("%s_APP_SUBNET_%d",var.name_space , count.index)))}"
}



resource "aws_eip" "nateip" {
  vpc   = true
  count = "${length(var.nat_subnet)}" 
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = "${element(aws_eip.nateip.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.nat_subnet.*.id, count.index)}"
  count         = "${length(var.nat_subnet)}"

  depends_on = ["aws_internet_gateway.myvpc"]
}

resource "aws_route_table" "public_route" {
  vpc_id           = "${aws_vpc.myvpc.id}"
  tags             = "${merge(var.tags, map("Name", "PUBLIC_ROUTE"))}"
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public_route.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.myvpc.id}"
}



resource "aws_route_table" "private_route" {
  vpc_id           = "${aws_vpc.myvpc.id}"
  count            = "${length(var.nat_subnet)}"
  tags             = "${merge(var.tags, map("Name", format("PRIVATE_ROUTE_%d", count.index)))}"
# have the change the count based on the nat subnets
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${element(aws_route_table.private_route.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.natgw.*.id, count.index)}"
  count                  = "${length(var.nat_subnet)}"
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.nat_subnet) + length(var.ssh_subnet) +  length(var.public_elb_subnet) }"
  subnet_id      = "${element( concat(aws_subnet.nat_subnet.*.id, aws_subnet.ssh_subnet.*.id,aws_subnet.public_elb_subnet.*.id) , count.index)}"
  route_table_id = "${aws_route_table.public_route.id}"
}

resource "aws_route_table_association" "private" {
  count          = "${length(var.app_subnet) + length(var.db_subnet)}"
  subnet_id      = "${element( concat(aws_subnet.app_subnet.*.id, aws_subnet.db_subnet.*.id) , count.index)}"
  route_table_id = "${element(aws_route_table.private_route.*.id, count.index)}"
}


# security groups begin



resource "aws_security_group" "SSH_SEC_GRP" {
    name = "SSH_SEC_GRP"
    description = "Security Group For SSH"
    vpc_id = "${aws_vpc.myvpc.id}"
    tags  = "${merge(var.tags, map("Name", format("%s_SSH_SEC_GRP",var.name_space)))}"

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group_rule" "ssh_ips_rule" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    count = "${length(var.ssh_ips)}"
    cidr_blocks = ["${element(var.ssh_ips, count.index)}"]
    security_group_id =  "${aws_security_group.SSH_SEC_GRP.id}"
}

resource "aws_security_group" "APP_SEC_GRP" {
    name = "APP_SEC_GRP"
    description = "Security Group For APP"
    vpc_id = "${aws_vpc.myvpc.id}"
    tags  = "${merge(var.tags, map("Name", format("%s_APP_SEC_GRP",var.name_space)))}"


    # allows traffic from the SG itself for tcp
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups =  ["${aws_security_group.SSH_SEC_GRP.id}"]
    }

    ingress {
        from_port = "${var.app_running_port}"
        to_port = "${var.app_running_port}"
        protocol = "tcp"
        security_groups =  ["${aws_security_group.ELB_SEC_GRP.id}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_security_group" "ELB_SEC_GRP" {
    name = "ELB_SEC_GRP"
    description = "Security Group For ELB"
    vpc_id = "${aws_vpc.myvpc.id}"
    tags  = "${merge(var.tags, map("Name", format("%s_ELB_SEC_GRP",var.name_space)))}"

    # allows traffic from the SG itself for tcp
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
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

resource "aws_security_group" "DB_SEC_GRP" {
    name = "DB_SEC_GRP"
    description = "Security Group For DB"
    vpc_id = "${aws_vpc.myvpc.id}"
    tags  = "${merge(var.tags, map("Name", format("%s_DB_SEC_GRP",var.name_space)))}"
    # allows traffic from the SG itself for tcp
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups =  ["${aws_security_group.APP_SEC_GRP.id}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
# security group ends here

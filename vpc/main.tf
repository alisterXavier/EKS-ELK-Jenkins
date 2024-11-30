resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "VPC"
  }
}
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  availability_zone       = var.public_subnets[count.index].az
  cidr_block              = var.public_subnets[count.index].cidr
  tags = {
    "Name"                                      = "Public"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.private_subnets[count.index].az
  cidr_block        = var.private_subnets[count.index].cidr
  tags = {
    "Name"                                      = "Private"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_eip" "eip" {}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "nat"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "public_association" {
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}
resource "aws_route_table_association" "private_association" {
  count          = length(aws_subnet.private)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_security_group" "lb" {
  name = "FlamingThunder LB"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "FlamingThunder LB"
  }
}
resource "aws_security_group" "node_group" {
  name = "All Traffic Access"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "All Traffic Access"
  }
}

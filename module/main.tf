provider local {

  version = "~> 1.3"
}

provider template {

  version  = "~> 2.1"
}


provider aws {
  region     = var.REGION
  version    = "~> 2.7"
}


locals {
  azCount = var.AZ_COVERAGE == 0 ? length(data.aws_availability_zones.available.names) : var.AZ_COVERAGE
}

resource aws_vpc vpc {

  cidr_block = var.VPC_CIDR
  enable_dns_hostnames = true

  tags = map(
     "Name", format("%s-node", var.NAME),
     "kubernetes.io/cluster/${var.NAME}", "shared",
     "owner", var.OWNER_TAG,
     "project", var.PROJECT_TAG,
  )

}
# Internet gateway for public subnets
resource aws_internet_gateway gateway {

  depends_on = [aws_vpc.vpc]

  vpc_id = aws_vpc.vpc.id

  tags = {
    "Name" = format("%s", var.NAME),
    "owner" = var.OWNER_TAG,
    "project" = var.PROJECT_TAG,
  }
}
# Public subnet and routing
resource aws_subnet public_subnet {

  depends_on = [aws_vpc.vpc]
  count = local.azCount

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.PUBLIC_SUBNET_CIDRS[count.index]
  vpc_id            = aws_vpc.vpc.id

  tags = {
    "Name" = format("public_%s_az_%s", var.NAME, data.aws_availability_zones.available.names[count.index])
    "kubernetes.io/cluster/${var.NAME}" = "shared"
    "owner" = var.OWNER_TAG
    "project" = var.PROJECT_TAG
    "type" = format("public_%s", var.NAME)
  }
}

resource aws_route_table public_subnet_rtable {

  depends_on = [aws_vpc.vpc, aws_internet_gateway.gateway]

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    "Name" = format("%s-public_subnet_rtable", var.NAME)
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_route_table_association public_rt_association {

  depends_on = [aws_subnet.public_subnet, aws_route_table.public_subnet_rtable]

  count = local.azCount

  subnet_id      = aws_subnet.public_subnet.*.id[count.index]
  route_table_id = aws_route_table.public_subnet_rtable.id
}
#Elastic IP for nat gw:
resource "aws_eip" nat_gw_eip {
  vpc = true
  count = local.azCount
  tags = {
    "Name" = format("%s-nat_gw_eip", var.NAME)
    "kubernetes.io/cluster/${var.NAME}" = "shared"
    "owner" =  var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}
#Nat gateway for public subnet:
resource "aws_nat_gateway" nat_gw {
  depends_on = [aws_vpc.vpc,aws_subnet.public_subnet,aws_eip.nat_gw_eip]

  count = local.azCount
  subnet_id = aws_subnet.public_subnet.*.id[count.index]
  allocation_id =  aws_eip.nat_gw_eip.*.id[count.index]

  tags = {
    "Name" = format("%s-nat_gw_az_%s", var.NAME,data.aws_availability_zones.available.names[count.index])
    "kubernetes.io/cluster/${var.NAME}" = "shared"
    "owner" =  var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

# Private subnet and routing
resource aws_subnet private_subnet {

  depends_on = [aws_vpc.vpc]

  count = local.azCount

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.PRIVATE_SUBNET_CIDRS[count.index]
  vpc_id            = aws_vpc.vpc.id

  tags = {
    "Name" = format("private_%s_az_%s", var.NAME,data.aws_availability_zones.available.names[count.index])
    "kubernetes.io/cluster/${var.NAME}"= "shared"
    "owner" = var.OWNER_TAG
    "project" = var.PROJECT_TAG
    "type" = format("private_%s", var.NAME)
  }
}

resource aws_route_table private_subnet_rtable {

  depends_on = [aws_vpc.vpc, aws_nat_gateway.nat_gw]
  vpc_id = aws_vpc.vpc.id

  count = local.azCount

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id =aws_nat_gateway.nat_gw.*.id[count.index]
  }

  tags = {
    "Name" = format("%s-private_subnet_rtable_az_%s", var.NAME,data.aws_availability_zones.available.names[count.index])
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_route_table_association private_rt_association {

  depends_on = [aws_subnet.private_subnet, aws_route_table.private_subnet_rtable]
  count = local.azCount

  subnet_id      = aws_subnet.private_subnet.*.id[count.index]
  route_table_id = aws_route_table.private_subnet_rtable.*.id[count.index]
}

resource aws_security_group node {

  depends_on = [aws_vpc.vpc]

  name        = format("%s-node", var.NAME)
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "owner"   = var.OWNER_TAG
    "project" = var.PROJECT_TAG
  }
}

resource aws_security_group_rule node {

  depends_on = [aws_security_group.node]

  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "ingress"
}

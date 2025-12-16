# Default public VPC
# 172.31.0.0/16
# Public subnets:
# - 172.31.16.0/20 (eu-central-1a) | 172.31.96.0/20  (eu-central-1a) - private-snet-a
# - 172.31.32.0/20 (eu-central-1b) | 172.31.112.0/20 (eu-central-1b) - private-snet-b
# - 172.31.0.0/20  (eu-central-1c) | 172.31.128.0/20 (eu-central-1c) - private-snet-c

locals {

  private_subnets = {
    private-snet-a = {
      range = "172.31.96.0/20"
      index = 0
    }
    private-snet-b = {
      range = "172.31.112.0/20"
      index = 1
    }
    private-snet-c = {
      range = "172.31.128.0/20"
      index = 2
    }
  }

}

# CREATE NEW VPC BESIDE DEFAULT VPC LATER
resource "aws_subnet" "private" {
  for_each          = local.private_subnets
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = each.value.range
  availability_zone = data.aws_availability_zones.available.names[index(keys(local.private_subnets), each.key)]
  tags = {
    Name = "${each.key}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id
  tags   = { Name = "default-vpc-private-rt" }
}

resource "aws_route_table_association" "rta" {
  for_each       = local.private_subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private.id
}

# Add Elastic IP for NAT Gateway
# Elastic IP a NAT Gateway-hez
resource "aws_eip" "nat" {
  count  = local.nat ? 1 : 0
  domain = "vpc"
  tags = {
    Name = "default-vpc-natgw-eip"
  }
}

# Add Nat Gateway (in public subnet) and Routes later
resource "aws_nat_gateway" "nat" {
  count         = local.nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id

  # Here refer for existing public subnet
  # Example: if the 172.31.16.0/20 subnet is one of the public ones, find it and use its ID:
  subnet_id = data.aws_subnets.public.ids[0]

  tags = {
    Name = "default-vpc-natgw"
  }

  depends_on = [aws_eip.nat]
}

resource "aws_route" "private_default_nat" {
  count                  = local.nat ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

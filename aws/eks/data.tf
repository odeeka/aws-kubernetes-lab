data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "private" {
  filter {
    name = "vpc-id"
    values = [
      data.aws_vpc.default.id
    ]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = [false]
  }
}

data "aws_subnets" "public" {
  filter {
    name = "vpc-id"
    values = [
      data.aws_vpc.default.id
    ]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = [true]
  }
}
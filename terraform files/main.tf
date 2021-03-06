provider "aws" {
region  = "ap-south-1"
access_key = ""
secret_key = ""
}

#VPC
resource "aws_vpc" "tf_vpc" {
cidr_block = "10.4.0.0/16"
tags = {
Name = "Terraform_vpc"
}
}

#NACL
resource "aws_default_network_acl" "tf_nacl" {
    default_network_acl_id = aws_vpc.tf_vpc.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

#PUBLIC-SUBNET
resource "aws_subnet" "tf_subnet1" {
vpc_id= aws_vpc.tf_vpc.id
cidr_block= "10.4.0.0/25"
availability_zone = "ap-south-1a"
map_public_ip_on_launch = true

depends_on = [aws_internet_gateway.gw]
tags = {
Name = "Terraform_subnet1"
}
}

#NETWORK-INTERFACE-CARD
#resource "aws_network_interface" "net_interface1" {
#  subnet_id   = aws_subnet.tf_subnet1.id
  #private_ips = ["10.4.0.10"]

#  tags = {
#    Name = "primary_network_interface"
#  }
#}

#INTERNET-GATEWAY
resource "aws_internet_gateway" "gw" {
  #depends_on = [aws_vpc.tf_vpc,
  #  aws_subnet.tf_subnet1,
  #  aws_subnet.tf_subnet2]
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "internet_gateway"
  }
}

#PUBLIC-ROUTE-TABLE
resource "aws_route_table" "Public_Subnet_RT" {
  vpc_id = aws_vpc.tf_vpc.id
  depends_on = [
    aws_vpc.tf_vpc,
    aws_internet_gateway.gw
  ]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "Internet Gateway-RT"
  }
}

resource "aws_route_table_association" "RT-IG-Association" {

  depends_on = [
    aws_vpc.tf_vpc,
    aws_subnet.tf_subnet1,
    aws_subnet.tf_subnet2,
    aws_route_table.Public_Subnet_RT
  ]

# Public Subnet ID
  subnet_id      = aws_subnet.tf_subnet1.id

#  Route Table ID
  route_table_id = aws_route_table.Public_Subnet_RT.id
}

#PRIVATE-SUBNET
resource "aws_subnet" "tf_subnet2" {
vpc_id= aws_vpc.tf_vpc.id
cidr_block= "10.4.0.128/25"
availability_zone = "ap-south-1b"
tags = {
Name = "Terraform_subnet2"
}
}

#NAT-GATEWAY
resource "aws_nat_gateway" "NAT_GATEWAY" {
  depends_on = [
    aws_eip.nat_gateway_ip
  ]
  # Allocating the Elastic IP to the NAT Gateway!
  allocation_id = aws_eip.nat_gateway_ip.id
  # Associating it in the Public Subnet!
  subnet_id = aws_subnet.tf_subnet1.id
  tags = {
    Name = "Nat-Gateway"
  }
}

#ROUTE-TABLE FOR NAT-GATEWAY
resource "aws_route_table" "NAT_Gateway_RT" {
  depends_on = [
    aws_nat_gateway.NAT_GATEWAY
  ]
  vpc_id = aws_vpc.tf_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT_GATEWAY.id
  }
  tags = {
    Name = "Route-Table- NAT Gateway"
  }
}

#NAT-GATEWAY-RT-ASSOCIATION
resource "aws_route_table_association" "Nat_Gateway_RT_Association" {
  depends_on = [
    aws_route_table.NAT_Gateway_RT
  ]
#  Private Subnet ID for adding this route table to the DHCP server of Private subnet!
  subnet_id      = aws_subnet.tf_subnet2.id
# Route Table ID
  route_table_id = aws_route_table.NAT_Gateway_RT.id
}

#SECURITY-GROUP-EC2
resource "aws_security_group" "ec2_security_gp" {
  vpc_id      = aws_vpc.tf_vpc.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
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

#EC2-INSTANCE
resource "aws_instance" "ec2_instance" {
ami= "ami-0a4a70bd98c6d6441"
instance_type = "t2.micro"
subnet_id= aws_subnet.tf_subnet1.id
#private_ip=["10.4.0.20"]
key_name= "nginxPY"
tags = {
Name = "Terraform_instance"
}
security_groups = [aws_security_group.ec2_security_gp.id]

#NETWORK-INTERFACE-CARD-ATTACHMENT
#network_interface {
#network_interface_id = aws_network_interface.net_interface1.id
#device_index= 0
# }
}

#EBS-VOLUME-EC2
resource "aws_ebs_volume" "tf_volume" {
  availability_zone = "ap-south-1a"
  size              = 20

  tags = {
    Name = "tf_ebs_volume"
  }
}

#EBS-VOLUME-ATTACHMENT
resource "aws_volume_attachment" "tf_ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.tf_volume.id
  instance_id = aws_instance.ec2_instance.id
}

#EIP-EC2-INSTANCE
resource "aws_eip" "nat_gateway_ip"{
#instance = aws_instance.ec2_instance.id
vpc = true
depends_on = [aws_route_table_association.RT-IG-Association ]
}


//vpc/main.tf 

data "aws_availability_zones" "available" { }

resource "aws_vpc" "eks_vpc" {
  cidr_block = var.cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true 
  tags = {
    Name = "eks_vpc"
  }
  lifecycle {
    create_before_destroy = true
  }
}

locals {
  cluster_name = "education-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}


//creation of the public subnet 

resource "aws_subnet" "efs_public_subnet" {
  count = var.public_sn_count
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = var.public_cidrs[count.index]
  map_public_ip_on_launch = true 
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "efs_public_subnet-${count.index}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1

  }   
}

resource "aws_subnet" "efs_private_subnet" {
  count = var.private_sn_count
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = var.private_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "efs_private_subnet-${count.index}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }   
}

// creation of the internet gateway 

resource "aws_internet_gateway" "eks_gw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_gw"
  }
}

//creation of the eip 
resource "aws_eip" "eks_eip1" {
  domain = "vpc"
}

resource "aws_eip" "eks_eip2" {
  domain = "vpc"
}

// creation of the nat_gateway

resource "aws_nat_gateway" "eks_ng1" {
  allocation_id = aws_eip.eks_eip1.id 
  subnet_id = aws_subnet.efs_public_subnet.*.id[0]
  tags = {
    Name = "eks-ng1"
  }
}

resource "aws_nat_gateway" "eks_ng2" {
  allocation_id = aws_eip.eks_eip2.id 
  subnet_id = aws_subnet.efs_public_subnet.*.id[1]
  tags = {
    Name = "eks-ng2"
  }
}

// creation of the public route table 

resource "aws_route_table" "eks_public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_public_route_table"
  }
}

resource "aws_route" "eks_public_route" {
  gateway_id = aws_internet_gateway.eks_gw.id 
  route_table_id = aws_route_table.eks_public_route_table.id 
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table" "eks_private_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_public_route_table"
  }
}

resource "aws_route_table" "eks_private_route_table1" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_public_route_table1"
  }
}

resource "aws_route_table_association" "eks_public_route_table_assocaition" {
  count = var.public_sn_count
  subnet_id = aws_subnet.efs_public_subnet.*.id[count.index]
  route_table_id = aws_route_table.eks_public_route_table.id 
}

resource "aws_route" "eks_private_route" {
  route_table_id = aws_route_table.eks_private_route_table.id 
  nat_gateway_id = aws_nat_gateway.eks_ng1.id 
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "eks_private_route1" {
  route_table_id = aws_route_table.eks_private_route_table1.id 
  nat_gateway_id = aws_nat_gateway.eks_ng2.id 
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "eks_private_route_table_assocaition" {
  //count = var.public_sn_count
  subnet_id = aws_subnet.efs_private_subnet.*.id[0]
  route_table_id = aws_route_table.eks_private_route_table.id
}

resource "aws_route_table_association" "eks_private_route_table_assocaition1" {
  //count = var.public_sn_count
  subnet_id = aws_subnet.efs_private_subnet.*.id[1]
  route_table_id = aws_route_table.eks_private_route_table1.id
}

resource "aws_iam_role" "eks_role" {
  name = "eks-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
  })
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  //https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSClusterPolicy.html#AmazonEKSClusterPolicy-json  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks_role.name
}

resource "aws_eks_cluster" "eks" {
  name = "eks"
  role_arn = aws_iam_role.eks_role.arn
  version = "1.27"
  vpc_config {
    endpoint_public_access = true 
    endpoint_private_access = false 

    subnet_ids = [aws_subnet.efs_public_subnet.*.id[0],
    aws_subnet.efs_public_subnet.*.id[1],
    aws_subnet.efs_private_subnet.*.id[0],
    aws_subnet.efs_private_subnet.*.id[1]
    ]
  }
  depends_on = [ aws_iam_role_policy_attachment.amazon_eks_cluster_policy ]
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
  })
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  //https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSClusterPolicy.html#AmazonEKSClusterPolicy-json  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy_general" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "worker_node" {
  cluster_name = aws_eks_cluster.eks.name 
  node_group_name = "eks_worker_node"
  node_role_arn = aws_iam_role.eks_node_role.arn 
  subnet_ids = aws_subnet.efs_private_subnet.*.id 
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  ami_type = "AL2_x86_64"
  capacity_type = "ON_DEMAND"
  disk_size = 20
  force_update_version = false 
  instance_types = ["t3.small"]
  labels = {
    role = "worker_nodes"
  }
  depends_on = [ aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy_general,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only
   ]
}



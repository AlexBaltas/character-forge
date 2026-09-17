resource "aws_vpc" "Character_forge" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "character-forge-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.Character_forge.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "character-forge-public-subnet"
  }
}

resource "aws_internet_gateway" "character_forge" {
  vpc_id = aws_vpc.Character_forge.id

  tags = {
    Name = "character-forge-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.Character_forge.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.character_forge.id
  }

  tags = {
    Name = "character-forge-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "web" {
  name        = "character-forge-web-rg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.Character_forge.id
  tags = {
    name = "character-forge-web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}


resource "aws_vpc_security_group_ingress_rule" "SSH" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.web.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}




resource "aws_instance" "character_forge" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.character_forge.key_name
  iam_instance_profile   = aws_iam_instance_profile.character_forge.name

  tags = {
    name = "character-forge-server"
  }
}

resource "aws_key_pair" "character_forge" {
  key_name   = "character-forge-key"
  public_key = file("${path.module}/../character-forge-key-new.pub")

  tags = {
    name = "character-forge-key"
  }
}

resource "aws_iam_role" "ec2_ecr_role" {
  name = "character-forge-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "character_forge" {
  name = "character-forge-instance-profile"
  role = aws_iam_role.ec2_ecr_role.name
}


resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "character-forge-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:AlexBaltas@56007143/character-forge@1355262975:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "character-forge-ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]

        Resource = "arn:aws:ecr:us-east-2:491085406494:repository/character-forge"
      }
    ]
  })
}
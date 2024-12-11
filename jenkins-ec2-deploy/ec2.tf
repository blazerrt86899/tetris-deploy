data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_iam_role" "jenkins-role" {
  name = "jenkins-terraform-role"

  assume_role_policy = <<EOF
  {
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
}
EOF
}

resource "aws_iam_role_policy_attachment" "jenkins-role-attachment" {
  role = aws_iam_role.jenkins-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "instance-profile" {
  name = "Jenkins-Terraform-Instance-Profile"
  role = aws_iam_role.jenkins-role.name
}

resource "aws_security_group" "jenkins-sg" {
  name = "Jenkins-Security-Group"
  description = "Allow 22,443,80,8080,9000"
  ingress = [
    for port in [22, 443, 80, 8080, 9000, 3000] : {
        description = "TLS from VPC"
        from_port = port
        to_port = port
        protocol = "tcp"
        cidr_blocks = var.cidr_blocks
        ipv6_cidr_blocks = []
        prefix_list_ids = []
        security_groups = []
        self = false
    }
  ]

  egress = [{
    description = "TLS from VPC"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self = false
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    security_groups = []

  }]

  tags = {
    Name = "Jenkins-sg"
  }
}


resource "aws_instance" "jenkins-instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.medium"
  key_name = "EC2-DocDBKeyPair"

  vpc_security_group_ids = [aws_security_group.jenkins-sg.id]
  user_data = templatefile("./install-jenkins.sh", {})

  iam_instance_profile = aws_iam_instance_profile.instance-profile.name

  root_block_device {
    volume_size = 30
  }

  tags = {
    Name = "JenkinsMaster"
  }
}
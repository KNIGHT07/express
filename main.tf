provider "aws" {
  region = "us-east-1"
  access_key = "AKIA3EPLXIGH7NHSL54S"
  secret_key = "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"
}

resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_route_table" "demo_route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_route_table_association" "demo_route_table_association" {
  subnet_id = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_route_table.id
}

resource "aws_route_table_association" "demo_route_table_association2" {
  subnet_id = aws_subnet.demo_subnet2.id
  route_table_id = aws_route_table.demo_route_table.id
}

resource "aws_ecs_cluster" "demo_cluster" {
  name = "demo-cluster"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_subnet" "demo_subnet" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_subnet" "demo_subnet2" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


resource "aws_security_group" "demo_sg" {
  name_prefix = "demo-sg-"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

data "aws_ecr_repository" "demo_repo" {
  name = "my-demo-app"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_ecs_task_definition" "demo_task_definition" {
  family                   = "demo-task"
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "demo-container"
    image     = data.aws_ecr_repository.demo_repo.repository_url
    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]
  }])

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


resource "aws_ecs_service" "demo_service" {
  name            = "demo-service"
  cluster         = aws_ecs_cluster.demo_cluster.arn
  task_definition = aws_ecs_task_definition.demo_task_definition.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.demo_sg.id]
    subnets         = [aws_subnet.demo_subnet.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.demo_target_group.arn
    container_name   = "demo-container"
    container_port   = 3000
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_lb" "demo_lb" {
  name               = "demo-lb"
  internal           = false
  load_balancer_type = "application"

  subnets = [aws_subnet.demo_subnet.id, aws_subnet.demo_subnet2.id]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


resource "aws_lb_target_group" "demo_target_group" {
  name     = "demo-target-group"
  port     = 3000
  protocol = "HTTP"

  vpc_id        = aws_vpc.demo_vpc.id
  target_type   = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
  }

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_lb_listener" "demo_listener" {
  load_balancer_arn = aws_lb.demo_lb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
  target_group_arn = aws_lb_target_group.demo_target_group.arn
  type = "forward"
}

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

variable "image_tag" {
  description = "The tag of the Docker image to use"
  type        = string
}

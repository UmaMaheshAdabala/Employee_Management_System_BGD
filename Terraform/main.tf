# VPC
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "myVPC"
  }
}


#Subnet - Public
resource "aws_subnet" "my-public-subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  count                   = 2
  availability_zone       = var.my-public-subnet.availability_zone[count.index]
  cidr_block              = var.my-public-subnet.cidr_block[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = var.my-public-subnet.name[count.index]
  }
}

#Subnet - Private
resource "aws_subnet" "my-private-subnet" {
  vpc_id            = aws_vpc.my-vpc.id
  count             = 3
  availability_zone = var.my-private-subnet.availability_zone[count.index]
  cidr_block        = var.my-private-subnet.cidr_block[count.index]
  tags = {
    Name = var.my-private-subnet.name[count.index]
  }
}

# IGW
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "myIGW"
  }
}

# Elastic IP
resource "aws_eip" "my-nat-eip" {
  tags = {
    Name = "myNATEIP"
  }
}

#NAT GATEWAY
resource "aws_nat_gateway" "my-nat" {
  allocation_id = aws_eip.my-nat-eip.id
  subnet_id     = aws_subnet.my-public-subnet[0].id
  tags = {
    Name = "myNATGateway"
  }
  depends_on = [aws_internet_gateway.my-igw]
}


#Public Route Table
resource "aws_route_table" "my-public-rt" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "myPublicRT"
  }
}

#Public Route
resource "aws_route" "my-route" {
  route_table_id         = aws_route_table.my-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my-igw.id
}

#Private Route Table
resource "aws_route_table" "my-private-rt" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "myPrivateRT"
  }
}

#Private Route
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.my-private-rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my-nat.id
}


#Public Route Association 
resource "aws_route_table_association" "my-public-route-association" {
  route_table_id = aws_route_table.my-public-rt.id
  count          = 2
  subnet_id      = aws_subnet.my-public-subnet[count.index].id
}

#Private Route Association
resource "aws_route_table_association" "my-private-route-association" {
  route_table_id = aws_route_table.my-private-rt.id
  count          = 3
  subnet_id      = aws_subnet.my-private-subnet[count.index].id
}

#Security Group for ALB
resource "aws_security_group" "my-alb-sg" {
  name   = "myALBSG"
  vpc_id = aws_vpc.my-vpc.id
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
}

#Security Group for ECS
resource "aws_security_group" "my-ecs-sg" {
  name   = "myECSSG"
  vpc_id = aws_vpc.my-vpc.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.my-alb-sg.id]
  }
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.my-alb-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Security group for RDS
resource "aws_security_group" "my-rds-sg" {
  name   = "myRDSSG"
  vpc_id = aws_vpc.my-vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.my-ecs-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Subnetgroup

resource "aws_db_subnet_group" "my-rds-subnet" {
  name       = "my-rds-subnet-group"
  subnet_ids = [aws_subnet.my-private-subnet[0].id, aws_subnet.my-private-subnet[2].id]
}

# Mysql RDS
resource "aws_db_instance" "my-sql-rds" {
  identifier             = "employees-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "employees_db"
  username               = var.db-username
  password               = var.db-password
  db_subnet_group_name   = aws_db_subnet_group.my-rds-subnet.id
  vpc_security_group_ids = [aws_security_group.my-rds-sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  tags = {
    Name = "mySQLRDS"
  }
}

#ALB
resource "aws_lb" "my-alb" {
  name               = "myALB"
  load_balancer_type = "application"
  subnets            = [aws_subnet.my-public-subnet[0].id, aws_subnet.my-public-subnet[1].id]
  security_groups    = [aws_security_group.my-alb-sg.id]
  internal           = false
}

#ALB Target Group(Frontend-Blue)
resource "aws_alb_target_group" "my-alb-tg-frontend-blue" {
  name        = "myTGFrontendBlue"
  vpc_id      = aws_vpc.my-vpc.id
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
}

#ALB Target Group(Frontend-Green)
resource "aws_alb_target_group" "my-alb-tg-frontend-green" {
  name        = "myTGFrontendGreen"
  vpc_id      = aws_vpc.my-vpc.id
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
}

#ALB Target Group(Backend-Blue)
resource "aws_alb_target_group" "my-alb-tg-backend-blue" {
  name        = "myTGBackendBlue"
  vpc_id      = aws_vpc.my-vpc.id
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#ALB Target Group(Backend-Green)
resource "aws_alb_target_group" "my-alb-tg-backend-green" {
  name        = "myTGBackendGreen"
  vpc_id      = aws_vpc.my-vpc.id
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#ALB Listener (fronend by default)
resource "aws_alb_listener" "my-alb-listener" {
  load_balancer_arn = aws_lb.my-alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_alb_target_group.my-alb-tg-frontend-blue.arn
        weight = 80
      }
      target_group {
        arn    = aws_alb_target_group.my-alb-tg-frontend-green.arn
        weight = 20
      }
    }
  }
}

#ALB Listener rule
resource "aws_alb_listener_rule" "my-alb-listener-backend" {
  listener_arn = aws_alb_listener.my-alb-listener.arn
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_alb_target_group.my-alb-tg-backend-blue.arn
        weight = 80
      }
      target_group {
        arn    = aws_alb_target_group.my-alb-tg-backend-green.arn
        weight = 20
      }
    }
  }
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

#Role for Task Definition ( ECS Execution Role)
resource "aws_iam_role" "my-exec-role" {
  name               = "myExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume-role.json
}

#Policy Doc
data "aws_iam_policy_document" "assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

#Attach Permission
resource "aws_iam_role_policy_attachment" "name" {
  role       = aws_iam_role.my-exec-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


#ECR REPO(frontend-blue)
resource "aws_ecr_repository" "my-ecr-frontend-blue" {
  name = "my-ecr-repo-frontend-blue"
}
#ECR Repo(Frontend-green)
resource "aws_ecr_repository" "my-ecr-frontend-green" {
  name = "my-ecr-repo-frontend-green"
}

#ECR Repo(Backend-blue)
resource "aws_ecr_repository" "my-ecr-backend-blue" {
  name = "my-ecr-repo-backend-blue"
}
#ECR Repo(Backend-green)
resource "aws_ecr_repository" "my-ecr-backend-green" {
  name = "my-ecr-repo-backend-green"
}

# ECS Cluster
resource "aws_ecs_cluster" "my-ecs-cluster" {
  name = "myECSCLUSTER"
}

# Role fo Task Defintion ( ECS Task Role)

resource "aws_iam_role" "ecs_task_role" {
  name = "myECSTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand",
          "ssm:StartSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
          "rds:DescribeDBInstances",
          "s3:GetObject",
          "s3:PutObject",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ssm:StartSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus"
        ],
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_task_ssm_managed" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}




#Task Definition (frontend-blue)
resource "aws_ecs_task_definition" "my-task-frontend-blue" {
  family       = "my-frontend-task-blue"
  network_mode = "awsvpc"

  requires_compatibilities = ["FARGATE"] # For fargate

  cpu                = "512"
  memory             = "1024"
  execution_role_arn = aws_iam_role.my-exec-role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "my-frontend-container",
      image     = aws_ecr_repository.my-ecr-frontend-blue.repository_url,
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80
        }
      ],
      memory = 717,
      cpu    = 512,
      # To enable exec
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}

#Task Definition (frontend-green)
resource "aws_ecs_task_definition" "my-task-frontend-green" {
  family       = "my-frontend-task-green"
  network_mode = "awsvpc"

  requires_compatibilities = ["FARGATE"] # For fargate

  cpu                = "512"
  memory             = "1024"
  execution_role_arn = aws_iam_role.my-exec-role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "my-frontend-container",
      image     = aws_ecr_repository.my-ecr-frontend-green.repository_url,
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80
        }
      ],
      memory = 717,
      cpu    = 512,
      # To enable exec
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}


#Task Definition (Backend-blue)
resource "aws_ecs_task_definition" "my-task-backend-blue" {
  family                   = "my-backend-task-blue"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"] # For fargate
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.my-exec-role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "my-backend-container",
      image     = aws_ecr_repository.my-ecr-backend-blue.repository_url,
      essential = true,
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000
        }
      ],
      memory = 717,
      cpu    = 512,
      environment = [
        {
          name  = "DATABASE_ENDPOINT",
          value = aws_db_instance.my-sql-rds.address
        },
        {
          name  = "DATABASE_USER",
          value = aws_db_instance.my-sql-rds.username
        },
        {
          name  = "DATABASE_PASSWORD",
          value = aws_db_instance.my-sql-rds.password
        },
        {
          name  = "FRONTEND_URL",
          value = "http://${aws_lb.my-alb.dns_name}"
        }
      ],
      # To enable exec
      linuxParameters = {
        initProcessEnabled = true
      }

    }
  ])
}

#Task Definition (Backend-green)
resource "aws_ecs_task_definition" "my-task-backend-green" {
  family                   = "my-backend-task-green"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"] # For fargate
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.my-exec-role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "my-backend-container",
      image     = aws_ecr_repository.my-ecr-backend-green.repository_url,
      essential = true,
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000
        }
      ],
      memory = 717,
      cpu    = 512,
      environment = [
        {
          name  = "DATABASE_ENDPOINT",
          value = aws_db_instance.my-sql-rds.address
        },
        {
          name  = "DATABASE_USER",
          value = aws_db_instance.my-sql-rds.username
        },
        {
          name  = "DATABASE_PASSWORD",
          value = aws_db_instance.my-sql-rds.password
        },
        {
          name  = "FRONTEND_URL",
          value = "http://${aws_lb.my-alb.dns_name}"
        }
      ],
      # To enable exec
      linuxParameters = {
        initProcessEnabled = true
      }

    }
  ])

}


# ECS service (frontend-blue)
resource "aws_ecs_service" "my-ecs-service-frontend-blue" {
  name            = "myECSFrontendServiceBlue"
  cluster         = aws_ecs_cluster.my-ecs-cluster.id
  task_definition = aws_ecs_task_definition.my-task-frontend-blue.arn
  desired_count   = 1
  launch_type     = "FARGATE" # For fargate
  network_configuration {
    subnets          = [aws_subnet.my-private-subnet[1].id]
    security_groups  = [aws_security_group.my-ecs-sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.my-alb-tg-frontend-blue.arn
    container_name   = "my-frontend-container"
    container_port   = 80
  }
  enable_execute_command = true
  depends_on = [aws_alb_listener.my-alb-listener,
  aws_ecs_cluster.my-ecs-cluster]
}
# ECS Service (frontend-green)
resource "aws_ecs_service" "my-ecs-service-frontend-green" {
  name            = "myECSFrontendServiceGreen"
  cluster         = aws_ecs_cluster.my-ecs-cluster.id
  task_definition = aws_ecs_task_definition.my-task-frontend-green.arn
  desired_count   = 1
  launch_type     = "FARGATE" # For fargate
  network_configuration {
    subnets          = [aws_subnet.my-private-subnet[1].id]
    security_groups  = [aws_security_group.my-ecs-sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.my-alb-tg-frontend-green.arn
    container_name   = "my-frontend-container"
    container_port   = 80
  }
  enable_execute_command = true
  depends_on = [aws_alb_listener.my-alb-listener,
  aws_ecs_cluster.my-ecs-cluster]
}

#ECS Service (backend-blue)
resource "aws_ecs_service" "my-ecs-service-backend-blue" {
  name            = "myECSBackendServiceBlue"
  cluster         = aws_ecs_cluster.my-ecs-cluster.id
  task_definition = aws_ecs_task_definition.my-task-backend-blue.arn
  desired_count   = 1
  launch_type     = "FARGATE" # For fargate
  network_configuration {
    subnets          = [aws_subnet.my-private-subnet[1].id]
    security_groups  = [aws_security_group.my-ecs-sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.my-alb-tg-backend-blue.arn
    container_name   = "my-backend-container"
    container_port   = 3000
  }
  enable_execute_command = true
  depends_on = [aws_alb_listener.my-alb-listener,
  aws_ecs_cluster.my-ecs-cluster]
}

#ECS Service (backend-green)
resource "aws_ecs_service" "my-ecs-service-backend-green" {
  name            = "myECSBackendServiceGreen"
  cluster         = aws_ecs_cluster.my-ecs-cluster.id
  task_definition = aws_ecs_task_definition.my-task-backend-green.arn
  desired_count   = 1
  launch_type     = "FARGATE" # For fargate
  network_configuration {
    subnets          = [aws_subnet.my-private-subnet[1].id]
    security_groups  = [aws_security_group.my-ecs-sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.my-alb-tg-backend-green.arn
    container_name   = "my-backend-container"
    container_port   = 3000
  }
  enable_execute_command = true
  depends_on = [aws_alb_listener.my-alb-listener,
  aws_ecs_cluster.my-ecs-cluster]
}




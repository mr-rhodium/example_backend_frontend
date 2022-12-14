resource "aws_ecr_repository" "BF" {
  name = "BF"
}

resource "aws_ecr_lifecycle_policy" "BF" {
  repository = aws_ecr_repository.BF.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep prod and latest tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 9999
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire images older than 7 days"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-task" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

variable "app_secret_key" {
  sensitive = true
}

resource "aws_ecs_task_definition" "BF" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([{
    name      = "BF"
    image     = "${aws_ecr_repository.BF.repository_url}:latest"
    essential = true
    environment = [
      {
        name  = "BF_BASE_URL"
        value = "https://bf-project.dev"
      },
      {
        name  = "BF_SECRET_KEY"
        value = var.app_secret_key
      },
      {
        name  = "BF_QUART_DB_DATABASE_URL"
        value = "postgresql://bf:${var.db_password}@${aws_db_instance.bf.endpoint}/bfdb"
      },
      {
        name  = "BF_QUART_AUTH_COOKIE_SECURE"
        value = "true"
      },
      {
        name  = "BF_QUART_AUTH_COOKIE_SAMESITE"
        value = "Strict"
      }
    ]
    portMappings = [{
      protocol      = "tcp"
      containerPort = 8080
      hostPort      = 8080
    }]
  }])
}

resource "aws_ecs_cluster" "production" {
  name = "production"
}

resource "aws_ecs_service" "BF" {
  name            = "BF"
  cluster         = aws_ecs_cluster.production.id
  task_definition = aws_ecs_task_definition.BF.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_task.id]
    subnets          = aws_subnet.public.*.id
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.BF.arn
    container_name   = "BF"
    container_port   = 8080
  }
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

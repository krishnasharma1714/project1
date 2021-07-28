####### provider ####

provider "aws" {
  region  = "us-east-1" # Setting region 
}

#### using  defult VPC/subnets companant  #########

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-east-1b"
}

######## role for ECS ###########
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

####### policy for role ######

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

###### attached the role ########

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

######  creation of 2 ECR repo  #######

resource "aws_ecr_repository" "my_flask" {
  name = "my-flask" # fask repo name 
}


###### make cluster #####
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster" # cluster name 
}



######### make our flask task defination #########

resource "aws_ecs_task_definition" "my_first_flask" {
  family                   = "my_first_flask" 
  container_definitions    = <<DEFINITION
  [
    {
      "name": "my_first_flask",
      "image": "${aws_ecr_repository.my_flask.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] 
  network_mode             = "awsvpc"    
  memory                   = 512         
  cpu                      = 256         
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}




#############  flask service #####


resource "aws_ecs_service" "my_service" {
  name            = "my_service"                             
  cluster         = "${aws_ecs_cluster.my_cluster.id}"             
  task_definition = "${aws_ecs_task_definition.my_first_flask.arn}" 
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.my_first_flask.family}"
    container_port   = 5000 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}","${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Setting the security group
  }

}





##### making load balncer #######

resource "aws_alb" "application_load_balancer" {
  name               = "my-lb-tf" # name of  load balancer
  load_balancer_type = "application"
  subnets = [ # Referencing   default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # Referencing  security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

#### Creating a security group for the load balancer ########

resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80 # Allowing traffic in from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

####### directing  traffic, making  target group and listener ####

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" # Referencing default VPC
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" # Referencing load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing tagrte group
  }
}



#####  creating security group ##

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}


output "dns_name" {
  value = aws_alb.application_load_balancer.dns_name
}

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





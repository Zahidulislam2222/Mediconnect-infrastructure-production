resource "aws_eks_cluster" "secondary" {
  name     = "${var.project}-${var.environment}-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

resource "aws_eks_node_group" "secondary_nodes" {
  cluster_name    = aws_eks_cluster.secondary.name
  node_group_name = "secondary-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t3.xlarge"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy,
  ]
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# IAM Role for EKS Nodes
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_lambda_function" "video_service" {
  filename      = "${path.module}/../../../src/video-service/video-service.zip"
  function_name = "${var.project}-${var.environment}-video-service"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [data.archive_file.video_service_zip]
}

resource "aws_lambda_function" "ai_analysis" {
  filename      = "${path.module}/../../../src/ai-analysis/ai-analysis.zip"
  function_name = "${var.project}-${var.environment}-ai-analysis"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [data.archive_file.ai_analysis_zip]
}

resource "aws_lambda_function" "iot_core" {
  filename      = "${path.module}/../../../src/iot-core/iot-core.zip"
  function_name = "${var.project}-${var.environment}-iot-core"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = "python3.11"
  timeout       = 60

  depends_on = [data.archive_file.iot_core_zip]
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project}-${var.environment}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach Basic Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- BUILD & ZIP (Symptom Checker / AI Analysis) ---

# Python Build (AI Analysis)
resource "null_resource" "install_python_ai_deps" {
  triggers = {
    requirements = filemd5("${path.module}/../../../src/ai-analysis/requirements.txt")
  }

  provisioner "local-exec" {
    command = "pip install -r ${path.module}/../../../src/ai-analysis/requirements.txt -t ${path.module}/../../../src/ai-analysis/"
  }
}

data "archive_file" "ai_analysis_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/ai-analysis"
  output_path = "${path.module}/../../../src/ai-analysis/ai-analysis.zip"
  depends_on  = [null_resource.install_python_ai_deps]
}

# Python Build (IoT Core)
resource "null_resource" "install_python_iot_deps" {
  triggers = {
    requirements = filemd5("${path.module}/../../../src/iot-core/requirements.txt")
  }

  provisioner "local-exec" {
    command = "pip install -r ${path.module}/../../../src/iot-core/requirements.txt -t ${path.module}/../../../src/iot-core/"
  }
}

data "archive_file" "iot_core_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/iot-core"
  output_path = "${path.module}/../../../src/iot-core/iot-core.zip"
  depends_on  = [null_resource.install_python_iot_deps]
}

# Node.js Build (Video Service)
resource "null_resource" "install_node_video_deps" {
  triggers = {
    package_json = filemd5("${path.module}/../../../src/video-service/package.json")
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/../../../src/video-service && npm install"
  }
}

data "archive_file" "video_service_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/video-service"
  output_path = "${path.module}/../../../src/video-service/video-service.zip"
  depends_on  = [null_resource.install_node_video_deps]
}

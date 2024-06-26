#Creating a code-commit repo
provider "aws" {
  region = "us-east-1"
}

resource "aws_codecommit_repository" "my_frontend_repo_final" {
  repository_name = var.frontend-repo-name
  description     = "Repository for Project"

  tags = {
    Environment = "Dev"
    Name        = "code_commit_p2"
  }
}

#pushing files to code-commit repo
resource "null_resource" "clone_repo" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir gitrepo_final
      pwd
      git clone ${aws_codecommit_repository.my_frontend_repo_final.clone_url_http} gitrepo_final/
      cp -r revhire-frontend/* gitrepo_final/
      cd gitrepo_final
      git add .
      git commit -m "Initial commit"
      git push -u origin master
    EOT
    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]
  }

  depends_on = [aws_codecommit_repository.my_frontend_repo_final]
  triggers = {
    always_run = timestamp()
  }
}

#Creating a s3 bucket
resource "aws_s3_bucket" "myfrontendbucket_final" {
  bucket = var.frontend-bucket-name

}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.myfrontendbucket_final.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#Giving public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.myfrontendbucket_final.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#Disabling acl controls
resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.myfrontendbucket_final.id
  acl    = "private"
}

# Bucket policy to allow public read access to objects
resource "aws_s3_bucket_policy" "mybucket_policy" {
  bucket = aws_s3_bucket.myfrontendbucket_final.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = [
				"s3:GetObject",
				"s3:PutObject"
			]
        Resource  = "${aws_s3_bucket.myfrontendbucket_final.arn}/*"
      }
    ]
  })
}

#Enabling static web hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.myfrontendbucket_final.id
  index_document {
    suffix = "index.html"
  }
}

output "static_web_hosting_url" {
  value = aws_s3_bucket.myfrontendbucket_final.website_endpoint
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role_final" {
  name = "codebuild-role-final"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodeBuild role
resource "aws_iam_role_policy" "codebuild_role_policy" {
  name   = "codebuild-role-policy-final"
  role   = aws_iam_role.codebuild_role_final.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sts:GetServiceBearerToken"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "codecommit:GitPull"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# CodeBuild project
resource "aws_codebuild_project" "codecommit_project_final" {
  name          = "codecommit-build-project-final"
  service_role  = aws_iam_role.codebuild_role_final.arn
  build_timeout = 30  # 30 minutes build timeout

  source {
    type            = "CODECOMMIT"
    location        = "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/${var.frontend-repo-name}"
    git_clone_depth = 1

    buildspec = <<EOF
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - echo Installing the Angular CLI...
      - npm install -g @angular/cli
  pre_build:
    commands:
      - echo Installing dependencies...
      - npm install
  build:
    commands:
      - echo Building the Angular application...
      - ng build --configuration production
  post_build:
    commands:
      - echo Build completed successfully.
      - echo Copying files to S3...
      - aws s3 cp dist/revhire/ s3://${var.frontend-bucket-name}/ --recursive

artifacts:
  files:
    - '**/*'
  base-directory: dist
  discard-paths: no
EOF
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true  # Needed for Docker commands
    image_pull_credentials_type = "CODEBUILD"
  }

  cache {
    type = "NO_CACHE"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/codecommit-build-project-final"
      stream_name = "build-log"
    }
  }
}
# Data source for AWS account details
data "aws_caller_identity" "current" {}

# CodePipeline
resource "aws_codepipeline" "codecommit_pipeline_final" {
  name     = "codecommit-pipeline-final"
  role_arn = aws_iam_role.codebuild_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.myfrontendbucket_final.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = aws_codecommit_repository.my_frontend_repo_final.repository_name
        BranchName     = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.codecommit_project_final.name
      }
    }
  }
}

output "pipeline_name" {
  value = aws_codepipeline.codecommit_pipeline_final.name
}
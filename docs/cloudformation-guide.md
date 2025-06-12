# AWS Infrastructure Deployment with CloudFormation

This guide covers deploying AWS infrastructure using CloudFormation templates with automated CI/CD pipeline using AWS CodePipeline, CodeBuild, and CodeCommit.

## 📋 Overview

The infrastructure deployment includes:
- **CloudFormation** templates for AWS services (VPC, Route Tables, NAT Gateway, EC2, Security Groups)
- **AWS CodePipeline** for automated build and deployment
- **AWS CodeBuild** with cfn-lint and TaskCat validation
- **AWS CodeCommit** for source code management

## 🏗️ Architecture

```
CodeCommit → CodePipeline → CodeBuild → CloudFormation → AWS Resources
```

## 📁 Project Structure

```
cloudformation/
├── infrastructure.yaml    # Main CloudFormation template
├── buildspec.yml         # CodeBuild build specification
└── README.md            # This file
```

## 🚀 Deployment Steps

### Step 1: Prerequisites Setup

#### 1.1 Install and Configure AWS CLI
```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your output format (json)
```

#### 1.2 Verify AWS CLI Configuration
```bash
aws sts get-caller-identity
```

### Step 2: Create Required AWS Resources

#### 2.1 Create S3 Bucket for Artifacts
```bash
# Create S3 bucket for storing build artifacts
aws s3 mb s3://your-cloudformation-artifacts-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-cloudformation-artifacts-bucket \
  --versioning-configuration Status=Enabled
```

#### 2.2 Create CodeCommit Repository
```bash
# Create CodeCommit repository
aws codecommit create-repository \
  --repository-name aws-infra-microservices \
  --repository-description "AWS Infrastructure for Microservices"

# Get repository clone URL
aws codecommit get-repository \
  --repository-name aws-infra-microservices
```

#### 2.3 Create IAM Roles

**CodeBuild Service Role:**
```bash
# Create trust policy for CodeBuild
cat > codebuild-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create CodeBuild service role
aws iam create-role \
  --role-name CodeBuildServiceRole \
  --assume-role-policy-document file://codebuild-trust-policy.json

# Attach policies to CodeBuild role
aws iam attach-role-policy \
  --role-name CodeBuildServiceRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

aws iam attach-role-policy \
  --role-name CodeBuildServiceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
  --role-name CodeBuildServiceRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

**CodePipeline Service Role:**
```bash
# Create trust policy for CodePipeline
cat > codepipeline-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create CodePipeline service role
aws iam create-role \
  --role-name CodePipelineServiceRole \
  --assume-role-policy-document file://codepipeline-trust-policy.json

# Create custom policy for CodePipeline
cat > codepipeline-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::your-cloudformation-artifacts-bucket",
        "arn:aws:s3:::your-cloudformation-artifacts-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:CancelUploadArchive",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetRepository",
        "codecommit:ListBranches",
        "codecommit:ListRepositories"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:UpdateStack",
        "cloudformation:CreateChangeSet",
        "cloudformation:DeleteChangeSet",
        "cloudformation:DescribeChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:SetStackPolicy",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create and attach policy
aws iam create-policy \
  --policy-name CodePipelineCustomPolicy \
  --policy-document file://codepipeline-policy.json

aws iam attach-role-policy \
  --role-name CodePipelineServiceRole \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/CodePipelineCustomPolicy
```

**CloudFormation Service Role:**
```bash
# Create trust policy for CloudFormation
cat > cloudformation-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudformation.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create CloudFormation service role
aws iam create-role \
  --role-name CloudFormationServiceRole \
  --assume-role-policy-document file://cloudformation-trust-policy.json

# Attach policies for infrastructure creation
aws iam attach-role-policy \
  --role-name CloudFormationServiceRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam attach-role-policy \
  --role-name CloudFormationServiceRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

### Step 3: Push Code to CodeCommit

#### 3.1 Configure Git for CodeCommit
```bash
# Configure Git credentials helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Clone the repository
git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/aws-infra-microservices
cd aws-infra-microservices
```

#### 3.2 Add CloudFormation Files
```bash
# Copy your CloudFormation files to the repository
cp /path/to/your/cloudformation/* ./

# Add and commit files
git add .
git commit -m "Initial CloudFormation infrastructure"
git push origin main
```

### Step 4: Create CodeBuild Project

```bash
# Create CodeBuild project
cat > codebuild-project.json << EOF
{
  "name": "microservices-infrastructure-build",
  "description": "Build project for microservices infrastructure",
  "source": {
    "type": "CODECOMMIT",
    "location": "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/aws-infra-microservices",
    "buildspec": "cloudformation/buildspec.yml"
  },
  "artifacts": {
    "type": "S3",
    "location": "your-cloudformation-artifacts-bucket",
    "packaging": "ZIP"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:3.0",
    "computeType": "BUILD_GENERAL1_SMALL",
    "environmentVariables": [
      {
        "name": "ARTIFACTS_BUCKET",
        "value": "your-cloudformation-artifacts-bucket"
      },
      {
        "name": "ENVIRONMENT",
        "value": "dev"
      }
    ]
  },
  "serviceRole": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodeBuildServiceRole"
}
EOF

# Create CodeBuild project
aws codebuild create-project --cli-input-json file://codebuild-project.json
```

### Step 5: Create CodePipeline

```bash
# Create CodePipeline
cat > codepipeline.json << EOF
{
  "pipeline": {
    "name": "microservices-infrastructure-pipeline",
    "roleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodePipelineServiceRole",
    "artifactStore": {
      "type": "S3",
      "location": "your-cloudformation-artifacts-bucket"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "SourceAction",
            "actionTypeId": {
              "category": "Source",
              "owner": "AWS",
              "provider": "CodeCommit",
              "version": "1"
            },
            "configuration": {
              "RepositoryName": "aws-infra-microservices",
              "BranchName": "main"
            },
            "outputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "BuildAction",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "microservices-infrastructure-build"
            },
            "inputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ],
            "outputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Deploy",
        "actions": [
          {
            "name": "DeployAction",
            "actionTypeId": {
              "category": "Deploy",
              "owner": "AWS",
              "provider": "CloudFormation",
              "version": "1"
            },
            "configuration": {
              "ActionMode": "CREATE_UPDATE",
              "StackName": "microservices-infrastructure",
              "TemplatePath": "BuildOutput::packaged-template.yaml",
              "Capabilities": "CAPABILITY_IAM",
              "RoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CloudFormationServiceRole",
              "ParameterOverrides": "{\"ProjectName\":\"microservices\",\"Environment\":\"dev\"}"
            },
            "inputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      }
    ]
  }
}
EOF

# Create pipeline
aws codepipeline create-pipeline --cli-input-json file://codepipeline.json
```

### Step 6: Trigger Pipeline

```bash
# Start pipeline execution
aws codepipeline start-pipeline-execution \
  --name microservices-infrastructure-pipeline

# Monitor pipeline status
aws codepipeline get-pipeline-state \
  --name microservices-infrastructure-pipeline
```

## 🔍 Monitoring and Validation

### Check Pipeline Status
```bash
# Get pipeline execution details
aws codepipeline list-pipeline-executions \
  --pipeline-name microservices-infrastructure-pipeline

# Check CloudFormation stack status
aws cloudformation describe-stacks \
  --stack-name microservices-infrastructure
```

### View Build Logs
```bash
# List CodeBuild builds
aws codebuild list-builds-for-project \
  --project-name microservices-infrastructure-build

# Get build logs
aws logs get-log-events \
  --log-group-name /aws/codebuild/microservices-infrastructure-build \
  --log-stream-name <LOG_STREAM_NAME>
```

### Validate Infrastructure
```bash
# List created resources
aws cloudformation list-stack-resources \
  --stack-name microservices-infrastructure

# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name microservices-infrastructure \
  --query 'Stacks[0].Outputs'
```

## 🛠️ Pipeline Features

### Build Stage (CodeBuild)
- **cfn-lint**: Validates CloudFormation template syntax
- **TaskCat**: Tests CloudFormation templates across regions
- **Template Packaging**: Prepares templates for deployment

### Deploy Stage (CloudFormation)
- **Stack Creation/Update**: Manages infrastructure lifecycle
- **Change Sets**: Reviews changes before deployment
- **Rollback**: Automatic rollback on failure

## 🔧 Customization

### Environment-Specific Deployments
```bash
# Create dev environment pipeline
aws codepipeline create-pipeline \
  --cli-input-json file://codepipeline-dev.json

# Create prod environment pipeline
aws codepipeline create-pipeline \
  --cli-input-json file://codepipeline-prod.json
```

### Parameter Overrides
Update the `ParameterOverrides` in the pipeline configuration:
```json
"ParameterOverrides": "{\"ProjectName\":\"microservices\",\"Environment\":\"prod\",\"InstanceType\":\"t3.small\"}"
```

## 🧹 Cleanup

### Delete Pipeline and Resources
```bash
# Delete pipeline
aws codepipeline delete-pipeline \
  --name microservices-infrastructure-pipeline

# Delete CodeBuild project
aws codebuild delete-project \
  --name microservices-infrastructure-build

# Delete CloudFormation stack
aws cloudformation delete-stack \
  --stack-name microservices-infrastructure

# Delete S3 bucket (empty first)
aws s3 rm s3://your-cloudformation-artifacts-bucket --recursive
aws s3 rb s3://your-cloudformation-artifacts-bucket

# Delete IAM roles
aws iam delete-role --role-name CodeBuildServiceRole
aws iam delete-role --role-name CodePipelineServiceRole
aws iam delete-role --role-name CloudFormationServiceRole
```

## 📚 Additional Resources

- [AWS CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/)
- [TaskCat Testing Guide](https://aws-quickstart.github.io/taskcat/)
- [cfn-lint Documentation](https://github.com/aws-cloudformation/cfn-lint)

## 🐛 Troubleshooting

### Common Issues
1. **IAM Permissions**: Ensure service roles have required permissions
2. **S3 Bucket**: Verify bucket exists and is accessible
3. **CodeCommit**: Check repository URL and credentials
4. **Build Failures**: Review CloudWatch logs for detailed errors

### Debug Commands
```bash
# Check IAM role permissions
aws iam get-role --role-name CodeBuildServiceRole

# Validate CloudFormation template locally
aws cloudformation validate-template \
  --template-body file://infrastructure.yaml

# Test cfn-lint locally
pip install cfn-lint
cfn-lint infrastructure.yaml
```
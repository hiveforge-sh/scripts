#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure AWS S3 + Route53 for HiveForge script redirects

.DESCRIPTION
    Creates S3 bucket with static website hosting and redirect rules,
    then configures Route53 to point get.hiveforge.sh to the bucket.

.PARAMETER Domain
    Base domain (default: hiveforge.sh)

.PARAMETER Subdomain
    Subdomain for scripts (default: get)

.PARAMETER Region
    AWS region for S3 bucket (default: us-east-1)

.EXAMPLE
    ./setup-aws-redirects.ps1
    ./setup-aws-redirects.ps1 -Region us-west-2
#>

param(
    [string]$Domain = "hiveforge.sh",
    [string]$Subdomain = "get",
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$BucketName = "$Subdomain.$Domain"

Write-Host "🔧 Setting up AWS redirects for $BucketName" -ForegroundColor Cyan
Write-Host ""

# Check AWS CLI
Write-Host "✓ Checking AWS CLI..." -ForegroundColor Yellow
try {
    $null = aws --version
    Write-Host "  ✅ AWS CLI found" -ForegroundColor Green
} catch {
    Write-Host "  ❌ AWS CLI not found. Install from: https://aws.amazon.com/cli/" -ForegroundColor Red
    exit 1
}

# Check AWS credentials
Write-Host "✓ Checking AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host "  ✅ Authenticated as: $($identity.Arn)" -ForegroundColor Green
} catch {
    Write-Host "  ❌ AWS credentials not configured. Run: aws configure" -ForegroundColor Red
    exit 1
}

# Step 1: Create S3 bucket
Write-Host "✓ Creating S3 bucket: $BucketName..." -ForegroundColor Yellow
try {
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $BucketName --region $Region 2>&1 | Out-Null
    } else {
        aws s3api create-bucket --bucket $BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region 2>&1 | Out-Null
    }
    Write-Host "  ✅ Bucket created" -ForegroundColor Green
} catch {
    if ($_ -match "BucketAlreadyOwnedByYou") {
        Write-Host "  ✅ Bucket already exists" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to create bucket: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Disable block public access
Write-Host "✓ Configuring bucket public access..." -ForegroundColor Yellow
$publicAccessConfig = @'
{
    "BlockPublicAcls": false,
    "IgnorePublicAcls": false,
    "BlockPublicPolicy": false,
    "RestrictPublicBuckets": false
}
'@
$publicAccessConfig | aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration file:///dev/stdin
Write-Host "  ✅ Public access configured" -ForegroundColor Green

# Step 3: Create redirect rules
Write-Host "✓ Creating redirect rules..." -ForegroundColor Yellow
$redirectRules = @'
{
    "IndexDocument": {
        "Suffix": "index.html"
    },
    "RoutingRules": [
        {
            "Condition": {
                "KeyPrefixEquals": "setup-repo.sh"
            },
            "Redirect": {
                "Protocol": "https",
                "HostName": "raw.githubusercontent.com",
                "ReplaceKeyWith": "hiveforge-sh/scripts/master/setup-repo/setup-repo-standards.sh",
                "HttpRedirectCode": "302"
            }
        },
        {
            "Condition": {
                "KeyPrefixEquals": "setup-repo.ps1"
            },
            "Redirect": {
                "Protocol": "https",
                "HostName": "raw.githubusercontent.com",
                "ReplaceKeyWith": "hiveforge-sh/scripts/master/setup-repo/setup-repo-standards.ps1",
                "HttpRedirectCode": "302"
            }
        },
        {
            "Condition": {
                "KeyPrefixEquals": "setup-repo"
            },
            "Redirect": {
                "Protocol": "https",
                "HostName": "github.com",
                "ReplaceKeyWith": "hiveforge-sh/scripts/tree/master/setup-repo",
                "HttpRedirectCode": "302"
            }
        }
    ]
}
'@

$redirectRules | aws s3api put-bucket-website --bucket $BucketName --website-configuration file:///dev/stdin
Write-Host "  ✅ Redirect rules configured" -ForegroundColor Green

# Step 4: Set bucket policy for public read
Write-Host "✓ Setting bucket policy..." -ForegroundColor Yellow
$bucketPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BucketName/*"
        }
    ]
}
"@

$bucketPolicy | aws s3api put-bucket-policy --bucket $BucketName --policy file:///dev/stdin
Write-Host "  ✅ Bucket policy set" -ForegroundColor Green

# Step 5: Get website endpoint
Write-Host "✓ Getting website endpoint..." -ForegroundColor Yellow
$websiteEndpoint = switch ($Region) {
    "us-east-1" { "$BucketName.s3-website-us-east-1.amazonaws.com" }
    "us-east-2" { "$BucketName.s3-website.us-east-2.amazonaws.com" }
    "us-west-1" { "$BucketName.s3-website-us-west-1.amazonaws.com" }
    "us-west-2" { "$BucketName.s3-website-us-west-2.amazonaws.com" }
    "eu-west-1" { "$BucketName.s3-website-eu-west-1.amazonaws.com" }
    "eu-central-1" { "$BucketName.s3-website.eu-central-1.amazonaws.com" }
    "ap-southeast-1" { "$BucketName.s3-website-ap-southeast-1.amazonaws.com" }
    "ap-southeast-2" { "$BucketName.s3-website-ap-southeast-2.amazonaws.com" }
    "ap-northeast-1" { "$BucketName.s3-website-ap-northeast-1.amazonaws.com" }
    default { "$BucketName.s3-website.$Region.amazonaws.com" }
}
Write-Host "  ✅ Endpoint: $websiteEndpoint" -ForegroundColor Green

# Step 6: Get hosted zone ID
Write-Host "✓ Finding Route53 hosted zone for $Domain..." -ForegroundColor Yellow
try {
    $hostedZones = aws route53 list-hosted-zones-by-name --dns-name $Domain | ConvertFrom-Json
    $zone = $hostedZones.HostedZones | Where-Object { $_.Name -eq "$Domain." } | Select-Object -First 1
    
    if (-not $zone) {
        Write-Host "  ⚠️  Hosted zone for $Domain not found" -ForegroundColor Yellow
        Write-Host "     Create one manually or use a different domain" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Manual Route53 setup required:" -ForegroundColor Cyan
        Write-Host "  1. Go to Route53 console: https://console.aws.amazon.com/route53" -ForegroundColor White
        Write-Host "  2. Select hosted zone: $Domain" -ForegroundColor White
        Write-Host "  3. Create A record:" -ForegroundColor White
        Write-Host "     - Name: $Subdomain" -ForegroundColor White
        Write-Host "     - Type: A" -ForegroundColor White
        Write-Host "     - Alias: Yes" -ForegroundColor White
        Write-Host "     - Target: $websiteEndpoint" -ForegroundColor White
        exit 0
    }
    
    $zoneId = $zone.Id -replace '/hostedzone/', ''
    Write-Host "  ✅ Hosted zone found: $zoneId" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Failed to find hosted zone: $_" -ForegroundColor Red
    exit 1
}

# Step 7: Get S3 hosted zone ID for alias
$s3HostedZoneId = switch ($Region) {
    "us-east-1" { "Z3AQBSTGFYJSTF" }
    "us-east-2" { "Z2O1EMRO9K5GLX" }
    "us-west-1" { "Z2F56UZL2M1ACD" }
    "us-west-2" { "Z3BJ6K6RIION7M" }
    "eu-west-1" { "Z1BKCTXD74EZPE" }
    "eu-central-1" { "Z21DNDUVLTQW6Q" }
    "ap-southeast-1" { "Z3O0J2DXBE1FTB" }
    "ap-southeast-2" { "Z1WCIGYICN2BYD" }
    "ap-northeast-1" { "Z2M4EHUR26P7ZW" }
    default { "Z3AQBSTGFYJSTF" }
}

# Step 8: Create Route53 A record
Write-Host "✓ Creating Route53 A record..." -ForegroundColor Yellow
$changeSet = @"
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$BucketName",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "$s3HostedZoneId",
                    "DNSName": "$websiteEndpoint",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}
"@

try {
    $changeSet | aws route53 change-resource-record-sets --hosted-zone-id $zoneId --change-batch file:///dev/stdin | Out-Null
    Write-Host "  ✅ DNS record created" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Failed to create DNS record: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Your new script URLs (HTTP only):" -ForegroundColor Cyan
Write-Host "  http://$BucketName/setup-repo.sh" -ForegroundColor White
Write-Host "  http://$BucketName/setup-repo.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  # Bash" -ForegroundColor White
Write-Host "  curl -sL http://$BucketName/setup-repo.sh | bash -s your-repo-name" -ForegroundColor White
Write-Host ""
Write-Host "  # PowerShell" -ForegroundColor White
Write-Host "  iwr http://$BucketName/setup-repo.ps1 -OutFile s.ps1; .\s.ps1 -Repo your-repo; rm s.ps1" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  Note: DNS propagation may take 5-10 minutes" -ForegroundColor Yellow
Write-Host ""
Write-Host "For HTTPS support, set up CloudFront:" -ForegroundColor Cyan
Write-Host "  1. Create CloudFront distribution pointing to $websiteEndpoint" -ForegroundColor White
Write-Host "  2. Request ACM certificate for *.hiveforge.sh in us-east-1" -ForegroundColor White
Write-Host "  3. Update Route53 A record to point to CloudFront distribution" -ForegroundColor White
Write-Host ""

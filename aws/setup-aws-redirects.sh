#!/usr/bin/env bash
#
# Configure AWS S3 + Route53 for HiveForge script redirects
#
# Usage:
#   ./setup-aws-redirects.sh [SUBDOMAIN] [REGION]
#   ./setup-aws-redirects.sh get us-east-1
#

set -euo pipefail

# Configuration
DOMAIN="${DOMAIN:-hiveforge.sh}"
SUBDOMAIN="${1:-get}"
REGION="${2:-us-east-1}"
BUCKET_NAME="$SUBDOMAIN.$DOMAIN"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'
NC='\033[0m'

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${CYAN}$1${NC}"
}

step() {
    echo -e "${YELLOW}✓ $1${NC}"
}

info "🔧 Setting up AWS redirects for $BUCKET_NAME"
echo ""

# Check AWS CLI
step "Checking AWS CLI..."
if ! command -v aws &> /dev/null; then
    error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
fi
success "  AWS CLI found"

# Check AWS credentials
step "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    error "AWS credentials not configured. Run: aws configure"
fi
IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
success "  Authenticated as: $IDENTITY"

# Step 1: Create S3 bucket
step "Creating S3 bucket: $BUCKET_NAME..."
if [ "$REGION" == "us-east-1" ]; then
    if aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" &> /dev/null; then
        success "  Bucket created"
    else
        success "  Bucket already exists"
    fi
else
    if aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION" &> /dev/null; then
        success "  Bucket created"
    else
        success "  Bucket already exists"
    fi
fi

# Step 2: Disable block public access
step "Configuring bucket public access..."
aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration '{
    "BlockPublicAcls": false,
    "IgnorePublicAcls": false,
    "BlockPublicPolicy": false,
    "RestrictPublicBuckets": false
}'
success "  Public access configured"

# Step 3: Create redirect rules
step "Creating redirect rules..."
cat > /tmp/website-config.json <<'EOF'
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
EOF

aws s3api put-bucket-website --bucket "$BUCKET_NAME" --website-configuration file:///tmp/website-config.json
rm /tmp/website-config.json
success "  Redirect rules configured"

# Step 4: Set bucket policy for public read
step "Setting bucket policy..."
cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file:///tmp/bucket-policy.json
rm /tmp/bucket-policy.json
success "  Bucket policy set"

# Step 5: Get website endpoint
step "Getting website endpoint..."
case "$REGION" in
    us-east-1) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website-us-east-1.amazonaws.com" ;;
    us-east-2) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website.us-east-2.amazonaws.com" ;;
    us-west-1) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website-us-west-1.amazonaws.com" ;;
    us-west-2) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website-us-west-2.amazonaws.com" ;;
    eu-west-1) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website-eu-west-1.amazonaws.com" ;;
    eu-central-1) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website.eu-central-1.amazonaws.com" ;;
    ap-southeast-1) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website-ap-southeast-1.amazonaws.com" ;;
    ap-southeast-2) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website-ap-southeast-2.amazonaws.com" ;;
    ap-northeast-1) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website-ap-northeast-1.amazonaws.com" ;;
    *) WEBSITE_ENDPOINT="$BUCKET_NAME.s3-website.$REGION.amazonaws.com" ;;
esac
success "  Endpoint: $WEBSITE_ENDPOINT"

# Step 6: Get hosted zone ID
step "Finding Route53 hosted zone for $DOMAIN..."
ZONE_JSON=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[?Name=='$DOMAIN.']" --output json)
ZONE_ID=$(echo "$ZONE_JSON" | jq -r '.[0].Id // empty' | sed 's|/hostedzone/||')

if [ -z "$ZONE_ID" ]; then
    warning "  Hosted zone for $DOMAIN not found"
    echo -e "${GRAY}     Create one manually or use a different domain${NC}"
    echo ""
    info "Manual Route53 setup required:"
    echo -e "${WHITE}  1. Go to Route53 console: https://console.aws.amazon.com/route53${NC}"
    echo -e "${WHITE}  2. Select hosted zone: $DOMAIN${NC}"
    echo -e "${WHITE}  3. Create A record:${NC}"
    echo -e "${WHITE}     - Name: $SUBDOMAIN${NC}"
    echo -e "${WHITE}     - Type: A${NC}"
    echo -e "${WHITE}     - Alias: Yes${NC}"
    echo -e "${WHITE}     - Target: $WEBSITE_ENDPOINT${NC}"
    exit 0
fi

success "  Hosted zone found: $ZONE_ID"

# Step 7: Get S3 hosted zone ID for alias
case "$REGION" in
    us-east-1) S3_HOSTED_ZONE_ID="Z3AQBSTGFYJSTF" ;;
    us-east-2) S3_HOSTED_ZONE_ID="Z2O1EMRO9K5GLX" ;;
    us-west-1) S3_HOSTED_ZONE_ID="Z2F56UZL2M1ACD" ;;
    us-west-2) S3_HOSTED_ZONE_ID="Z3BJ6K6RIION7M" ;;
    eu-west-1) S3_HOSTED_ZONE_ID="Z1BKCTXD74EZPE" ;;
    eu-central-1) S3_HOSTED_ZONE_ID="Z21DNDUVLTQW6Q" ;;
    ap-southeast-1) S3_HOSTED_ZONE_ID="Z3O0J2DXBE1FTB" ;;
    ap-southeast-2) S3_HOSTED_ZONE_ID="Z1WCIGYICN2BYD" ;;
    ap-northeast-1) S3_HOSTED_ZONE_ID="Z2M4EHUR26P7ZW" ;;
    *) S3_HOSTED_ZONE_ID="Z3AQBSTGFYJSTF" ;;
esac

# Step 8: Create Route53 A record
step "Creating Route53 A record..."
cat > /tmp/route53-change.json <<EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$BUCKET_NAME",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "$S3_HOSTED_ZONE_ID",
                    "DNSName": "$WEBSITE_ENDPOINT",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}
EOF

if aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file:///tmp/route53-change.json &> /dev/null; then
    rm /tmp/route53-change.json
    success "  DNS record created"
else
    rm /tmp/route53-change.json
    error "Failed to create DNS record"
fi

echo ""
info "🎉 Setup complete!"
echo ""
info "Your new script URLs (HTTP only):"
echo -e "${WHITE}  http://$BUCKET_NAME/setup-repo.sh${NC}"
echo -e "${WHITE}  http://$BUCKET_NAME/setup-repo.ps1${NC}"
echo ""
info "Usage:"
echo -e "${WHITE}  # Bash${NC}"
echo -e "${WHITE}  curl -sL http://$BUCKET_NAME/setup-repo.sh | bash -s your-repo-name${NC}"
echo ""
echo -e "${WHITE}  # PowerShell${NC}"
echo -e "${WHITE}  iwr http://$BUCKET_NAME/setup-repo.ps1 -OutFile s.ps1; .\\s.ps1 -Repo your-repo; rm s.ps1${NC}"
echo ""
warning "Note: DNS propagation may take 5-10 minutes"
echo ""
info "For HTTPS support, set up CloudFront:"
echo -e "${WHITE}  1. Create CloudFront distribution pointing to $WEBSITE_ENDPOINT${NC}"
echo -e "${WHITE}  2. Request ACM certificate for *.hiveforge.sh in us-east-1${NC}"
echo -e "${WHITE}  3. Update Route53 A record to point to CloudFront distribution${NC}"
echo ""

# Setup Instructions for AWS Redirects

## Prerequisites

1. **Install AWS CLI:**

   **Windows:**
   ```powershell
   winget install Amazon.AWSCLI
   # or download from: https://awscli.amazonaws.com/AWSCLIV2.msi
   ```

   **macOS:**
   ```bash
   brew install awscli
   ```

   **Linux:**
   ```bash
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **Configure AWS Credentials:**

   ```bash
   aws configure
   ```

   You'll need:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (suggest: us-east-1)
   - Output format (suggest: json)

   Get credentials from AWS Console:
   - IAM → Users → Your User → Security Credentials → Create Access Key

3. **Verify Route53 Hosted Zone:**

   ```bash
   aws route53 list-hosted-zones-by-name --dns-name hiveforge.sh
   ```

   If you don't have a hosted zone, create one:
   ```bash
   aws route53 create-hosted-zone \
     --name hiveforge.sh \
     --caller-reference $(date +%s)
   ```

## Run the Setup

Once prerequisites are met:

**PowerShell (Windows):**
```powershell
cd C:\Users\Preston\git\scripts\aws
.\setup-aws-redirects.ps1
```

**Bash (macOS/Linux):**
```bash
cd ~/git/scripts/aws  # or wherever you cloned it
./setup-aws-redirects.sh
```

## What Will Happen

The script will:
1. ✅ Create S3 bucket: `get.hiveforge.sh`
2. ✅ Configure website hosting with redirect rules
3. ✅ Set bucket policy for public read access
4. ✅ Create Route53 A record pointing to S3
5. ✅ Display your new short URLs

Expected output:
```
🎉 Setup complete!

Your new script URLs (HTTP only):
  http://get.hiveforge.sh/setup-repo.sh
  http://get.hiveforge.sh/setup-repo.ps1

Usage:
  # Bash
  curl -sL http://get.hiveforge.sh/setup-repo.sh | bash -s your-repo-name

  # PowerShell
  iwr http://get.hiveforge.sh/setup-repo.ps1 -OutFile s.ps1; .\s.ps1 -Repo your-repo; rm s.ps1

⚠️  Note: DNS propagation may take 5-10 minutes
```

## Testing

Wait 5-10 minutes for DNS propagation, then:

```bash
# Test the redirect
curl -I http://get.hiveforge.sh/setup-repo.sh
# Should see: HTTP/1.1 302 Found
# Location: https://raw.githubusercontent.com/...

# Test actual usage
curl -sL http://get.hiveforge.sh/setup-repo.sh | head -n 5
# Should show the script content
```

## Next Steps (Optional)

### Add HTTPS Support with CloudFront

1. Request ACM certificate (must be in us-east-1):
   ```bash
   aws acm request-certificate \
     --domain-name "*.hiveforge.sh" \
     --validation-method DNS \
     --region us-east-1
   ```

2. Validate certificate via Route53 DNS records (automated by AWS)

3. Create CloudFront distribution:
   ```bash
   aws cloudfront create-distribution \
     --origin-domain-name get.hiveforge.sh.s3-website-us-east-1.amazonaws.com \
     --default-root-object index.html
   ```

4. Update Route53 A record to point to CloudFront instead of S3

## Troubleshooting

### AWS CLI Not Found
Make sure you restart your terminal after installation, or add to PATH manually.

### Access Denied Errors
Your IAM user needs these permissions:
- S3: CreateBucket, PutBucketWebsite, PutBucketPolicy, PutPublicAccessBlock
- Route53: ListHostedZonesByName, ChangeResourceRecordSets

### Hosted Zone Not Found
The script will give you manual instructions if it can't find your Route53 hosted zone.

## Cost

Expected monthly cost: **$0.50 - $2.00**
- S3 storage: < $0.01
- S3 requests: $0.00 - $0.50
- Route53 hosted zone: $0.50
- Data transfer: $0.00 - $1.00 (first 1GB free)

With CloudFront: Still within free tier (10M requests, 50GB transfer/month)

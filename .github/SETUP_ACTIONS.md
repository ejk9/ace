# GitHub Actions Setup for AceApp

This document explains the GitHub Actions workflows configured for the AceApp project and how to set them up.

## 🚀 Workflows Overview

### 1. **CI Workflow** (`.github/workflows/ci.yml`)
**Trigger:** Push and PR to main/master/develop branches
**Purpose:** Comprehensive testing and quality assurance

- **Test Suite:** Elixir tests with PostgreSQL
- **End-to-End Tests:** Playwright browser automation
- **Code Quality:** Format checking, linting (Credo), compilation warnings
- **Security:** Dependency auditing
- **Coverage:** Test coverage reporting
- **Asset Building:** Frontend asset compilation

### 2. **Railway Deployment** (`.github/workflows/deploy-railway.yml`)
**Trigger:** Push to main/master, manual dispatch
**Purpose:** Automated deployment to Railway

- **Docker Build:** Multi-platform container building
- **Railway Deploy:** Automated deployment with health checks
- **Database Migrations:** Automatic migration execution
- **Game Data Setup:** Champion/skin data population
- **Health Monitoring:** Post-deployment verification

### 3. **Screenshot Service Deployment** (`.github/workflows/deploy-screenshot-service.yml`)
**Trigger:** Changes to `railway-functions/screenshot/`, manual dispatch
**Purpose:** Deploy serverless screenshot function

- **Function Deployment:** Railway Functions deployment
- **Environment Sync:** Update main app's screenshot service URL
- **Health Testing:** Function endpoint verification
- **Mock Testing:** Screenshot generation testing

### 4. **PR Quality Check** (`.github/workflows/pr-check.yml`)
**Trigger:** Pull request events
**Purpose:** Quality gate for pull requests

- **Quality Gate:** Same as CI but PR-focused
- **Bundle Size Impact:** Asset size comparison
- **Preview Deployment:** PR preview deployment setup
- **Security Scanning:** PR-specific security checks

### 5. **Release Management** (`.github/workflows/release.yml`)
**Trigger:** Git tags (v*.*.*), manual dispatch
**Purpose:** Production release automation

- **Release Creation:** GitHub release with changelog
- **Production Deployment:** Automated production deployment
- **Health Verification:** Extended production health checks
- **Notification System:** Release notifications

### 6. **Cleanup & Maintenance** (`.github/workflows/cleanup.yml`)
**Trigger:** Weekly schedule (Sundays 2 AM UTC), manual dispatch
**Purpose:** Automated maintenance tasks

- **Cache Cleanup:** GitHub Actions cache management
- **Security Audits:** Weekly security scans
- **Dependency Checks:** Update recommendations
- **Project Health:** Repository health reporting

## 🔧 Required Secrets

### Repository Secrets
Navigate to: `Settings > Secrets and variables > Actions`

#### Required Secrets:
```
RAILWAY_TOKEN
```
- **Description:** Railway CLI authentication token
- **How to get:** Run `railway auth` and copy the token from `~/.railway/config.json`
- **Used by:** All Railway deployment workflows

#### Optional Secrets:
```
DISCORD_WEBHOOK_URL
```
- **Description:** Discord webhook for deployment notifications
- **How to get:** Create webhook in Discord server settings
- **Used by:** Deployment notifications (currently commented out)

### Environment Variables
Set these in Railway, not GitHub:
- `DISCORD_CLIENT_ID`
- `DISCORD_CLIENT_SECRET`  
- `SECRET_KEY_BASE`
- `ADMIN_DISCORD_IDS`

## 🏗️ Setup Instructions

### 1. Enable GitHub Actions
```bash
# Ensure workflows directory exists
mkdir -p .github/workflows

# Verify workflows are present
ls -la .github/workflows/
```

### 2. Configure Railway Token
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Get your token (copy from the output)
cat ~/.railway/config.json

# Add RAILWAY_TOKEN to GitHub repository secrets
```

### 3. Set Up Environments
In GitHub repository settings:

1. **Go to:** `Settings > Environments`
2. **Create environments:**
   - `production` (for main branch deployments)
   - `staging` (optional, for preview deployments)

3. **Configure environment protection rules:**
   - Require reviewers for production
   - Restrict to specific branches

### 4. Test Workflows
```bash
# Trigger CI workflow
git push origin main

# Test PR workflow
git checkout -b test-actions
git commit --allow-empty -m "Test GitHub Actions"
git push origin test-actions
# Create PR on GitHub

# Test manual deployment
# Go to Actions tab > Deploy to Railway > Run workflow
```

## 📋 Workflow Status Badges

Add these to your README.md:

```markdown
![CI](https://github.com/your-username/ace-app/workflows/CI/badge.svg)
![Deploy to Railway](https://github.com/your-username/ace-app/workflows/Deploy%20to%20Railway/badge.svg)
![Screenshot Service](https://github.com/your-username/ace-app/workflows/Deploy%20Screenshot%20Service/badge.svg)
```

## 🔍 Monitoring & Debugging

### Check Workflow Status
1. **GitHub UI:** Actions tab in repository
2. **CLI:** `gh run list` (requires GitHub CLI)
3. **API:** GitHub REST API for programmatic access

### Common Issues & Solutions

#### ❌ "Railway token invalid"
**Solution:** Regenerate Railway token and update secret
```bash
railway logout
railway login
# Update RAILWAY_TOKEN secret in GitHub
```

#### ❌ "Database connection failed"
**Solution:** Check Railway PostgreSQL service
```bash
railway ps  # Check service status
railway logs  # Check logs
```

#### ❌ "Docker build failed"
**Solution:** Test Docker build locally
```bash
docker build -t ace-app-test .
```

#### ❌ "Tests failing in CI but passing locally"
**Solution:** Check environment differences
- Database version (CI uses PostgreSQL 14)
- Node.js version (CI uses Node 18)
- Environment variables missing

### Debugging Workflow Issues
```bash
# Enable debug logging in workflows
# Add this to workflow env:
ACTIONS_STEP_DEBUG: true
ACTIONS_RUNNER_DEBUG: true
```

## 🚀 Advanced Configuration

### Custom Notifications
Uncomment and configure Discord notifications in workflows:
```yaml
# Add Discord webhook URL to secrets
# Uncomment notification steps in workflows
```

### Preview Deployments
Set up branch-based preview deployments:
```bash
# Create preview Railway service
railway create --name ace-app-preview

# Configure branch-specific deployments in workflows
```

### Performance Monitoring
Add performance tracking to workflows:
```yaml
- name: Performance Test
  run: |
    # Add Lighthouse CI or other performance tools
    npm install -g @lhci/cli
    lhci collect --url=https://your-app.railway.app
```

## 🎯 Best Practices

1. **Secrets Management:**
   - Never commit secrets to repository
   - Rotate secrets regularly
   - Use environment-specific secrets

2. **Workflow Optimization:**
   - Use caching for dependencies
   - Run jobs in parallel when possible
   - Fail fast on critical errors

3. **Testing Strategy:**
   - Test workflows in feature branches
   - Use manual triggers for testing
   - Monitor workflow performance

4. **Security:**
   - Review workflow permissions
   - Use specific action versions (not @latest)
   - Enable security scanning

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Railway CLI Documentation](https://docs.railway.app/develop/cli)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Docker Best Practices](https://docs.docker.com/develop/best-practices/)

---

**Need help?** Check the Actions tab for workflow run details or create an issue for workflow-specific problems.
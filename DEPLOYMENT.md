# GitHub Actions Deployment Setup

This guide explains how to set up GitHub Actions for automated backend deployment to your VPS.

## Available Workflows

### 1. **Backend CI** (`backend-ci.yml`)
Runs on every push to `main`, `master`, or `develop` branches (and PRs).
- **Linting**: Checks Python syntax with flake8
- **Testing**: Runs database migrations and import checks
- **Docker Build**: Builds Docker image to verify it compiles

Runs before deployment to catch issues early.

### 2. **Deploy Backend** (`deploy-backend.yml`)
Triggers automatically when:
- Changes are pushed to `main` or `master` branch
- AND changes include: `backend/`, `docker-compose.yml`, or `deploy-contabo.sh`

Deploys to VPS via SSH and runs health checks.

---

## Setup Instructions

### Step 1: Generate SSH Key (on your local machine)

If you don't have an SSH key for GitHub Actions:

```bash
ssh-keygen -t ed25519 -f github-actions-deploy -C "github-actions@budgy" -N ""
```

This creates:
- `github-actions-deploy` (private key - keep secret!)
- `github-actions-deploy.pub` (public key - add to VPS)

### Step 2: Add Public Key to VPS

SSH into your VPS and add the public key:

```bash
ssh root@37.60.229.74
# On VPS:
mkdir -p ~/.ssh
echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Or copy with one command:

```bash
cat github-actions-deploy.pub | ssh root@37.60.229.74 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### Step 3: Add Secrets to GitHub

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add these:

| Name | Value |
|------|-------|
| `VPS_HOST` | `37.60.229.74` |
| `VPS_USER` | `root` |
| `VPS_PORT` | `22` |
| `VPS_SSH_KEY` | Contents of `github-actions-deploy` file (private key) |

**To copy the private key:**
```bash
cat github-actions-deploy
```
Copy the entire output (including `-----BEGIN OPENSSH PRIVATE KEY-----` lines) into the `VPS_SSH_KEY` secret.

### Step 4: Test the Workflow

1. Push a change to the backend:
   ```bash
   git add backend/
   git commit -m "Test GitHub Actions deployment"
   git push origin main
   ```

2. Go to your repository → **Actions** tab
3. Watch the workflow run:
   - First, backend CI checks run
   - If passed, deployment starts automatically
   - Monitor progress in real-time

---

## Workflow Details

### What Happens on Deployment?

1. **SSH into VPS** with the deploy key
2. **Navigate** to `/root/budgy` (or creates it)
3. **Git pull** latest changes from the repository
4. **Run** `deploy-contabo.sh` which:
   - Installs Docker (if needed)
   - Configures `.env` with secure passwords
   - Runs `docker compose up -d --build`
   - Executes database migrations
   - Checks API health endpoint
5. **Verify** `/health` endpoint returns 200 status

### What Stops a Deployment?

❌ Backend CI checks fail (syntax errors, import issues)
❌ Docker build fails
❌ API health check fails after deployment
❌ Database migrations fail

### Monitoring & Logs

Each workflow run shows:
- ✅ Which steps passed/failed
- 📋 Full logs of each step
- 🔍 Docker build output
- 🚀 SSH deployment output

### Manual Triggers

You can also manually trigger workflows:

1. Go to **Actions** → **Backend CI** (or **Deploy Backend**)
2. Click **Run workflow** dropdown
3. Select branch and click **Run workflow**

---

## Troubleshooting

### SSH Key Not Working
- Verify public key was added to `~/.ssh/authorized_keys` on VPS
- Check permissions: `chmod 600 ~/.ssh/authorized_keys`
- Test manually: `ssh -i github-actions-deploy root@37.60.229.74`

### Deployment Fails with "Permission denied"
- SSH key might not be properly formatted
- Ensure there are no extra spaces/newlines in GitHub secret
- Try removing and re-adding the secret

### API Health Check Fails
- Check VPS logs: `docker compose logs backend`
- Verify environment variables in `.env`
- Check database is running: `docker compose ps`

### Git Pull Fails
- Repository might not exist on VPS first time
- Workflow handles this by cloning if `.git` folder missing
- Manual fix: SSH into VPS and clone manually

---

## Security Best Practices

- ✅ Use SSH keys instead of passwords
- ✅ Use `ed25519` key type (more secure than RSA)
- ✅ Never commit private keys to Git
- ✅ Rotate deploy keys periodically
- ✅ Use read-only deploy key if possible (not applicable here, but good to know)
- ✅ Restrict secret to main branch deployments only

---

## Next Steps

1. **Generate and set up SSH keys** (Step 1-2)
2. **Add GitHub secrets** (Step 3)
3. **Test deployment** by pushing a small change (Step 4)
4. **Monitor logs** in Actions tab

Once set up, deployments are **fully automated**! 🚀

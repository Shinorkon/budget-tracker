#!/bin/bash
# GitHub Actions secrets setup helper
# This script helps you set up the necessary GitHub secrets for automated deployment

set -e

echo "🔐 GitHub Actions Deployment Setup Helper"
echo "=========================================="
echo ""

# Check if SSH key exists
if [ ! -f "github-actions-deploy" ]; then
    echo "📝 Generating SSH key for GitHub Actions..."
    ssh-keygen -t ed25519 -f github-actions-deploy -C "github-actions@budgy" -N ""
    echo "✅ SSH key generated:"
    echo "   - Private key: github-actions-deploy"
    echo "   - Public key: github-actions-deploy.pub"
    echo ""
fi

echo "📋 Next steps:"
echo "=============="
echo ""
echo "1️⃣  Add public key to your VPS (37.60.229.74):"
echo "    cat github-actions-deploy.pub | ssh root@37.60.229.74 \"mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys\""
echo ""
echo "2️⃣  Add these secrets to GitHub:"
echo "    Repository → Settings → Secrets and variables → Actions → New repository secret"
echo ""
echo "┌─────────────────┬──────────────────────────────────────┐"
echo "│ Secret Name     │ Value                                │"
echo "├─────────────────┼──────────────────────────────────────┤"
echo "│ VPS_HOST        │ 37.60.229.74                         │"
echo "│ VPS_USER        │ root                                 │"
echo "│ VPS_PORT        │ 22                                   │"
echo "│ VPS_SSH_KEY     │ (paste contents of below)            │"
echo "└─────────────────┴──────────────────────────────────────┘"
echo ""
echo "🔑 Copy this private key to VPS_SSH_KEY secret:"
echo "========================================================"
cat github-actions-deploy
echo ""
echo "========================================================"
echo ""
echo "3️⃣  Test the workflow:"
echo "    git add . && git commit -m 'Test CI/CD' && git push origin main"
echo ""
echo "4️⃣  Monitor deployment:"
echo "    Go to: GitHub → Repository → Actions tab"
echo ""
echo "✅ Setup complete! Your backend will auto-deploy on push to main branch."

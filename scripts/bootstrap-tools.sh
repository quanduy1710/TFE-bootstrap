#!/usr/bin/env bash
# bootstrap-tools.sh
# Checks and installs required tools on Ubuntu 22.04 (EC2).
# Run as root or with sudo.
#
# Tools installed:
#   - git, python3, jq  (via apt)
#   - AWS CLI v2        (official installer)
#   - kubectl           (latest stable, official binary)
#   - Terraform         (latest, HashiCorp apt repo)
#   - Helm              (latest, official installer script)
#   - Ansible           (latest ansible-core, official Ansible PPA)
#                       + Galaxy collections for the GitLab runbook
#                         (gitlab-ansible/requirements.yml)

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_REQUIREMENTS="${REPO_ROOT}/gitlab-ansible/requirements.yml"
# System-wide collections path — on Ansible's default search path for all users.
ANSIBLE_COLLECTIONS_PATH="/usr/share/ansible/collections"

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Guard: Ubuntu 22.04 only ─────────────────────────────────────────────────
if [[ "$(lsb_release -rs)" != "22.04" ]]; then
  error "This script targets Ubuntu 22.04. Detected: $(lsb_release -rs)"
fi

# ── Must run as root ──────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "Run this script as root or with sudo."
fi

# ── Helper: check if a command exists ────────────────────────────────────────
is_installed() { command -v "$1" &>/dev/null; }

# ── Update apt once ──────────────────────────────────────────────────────────
info "Updating apt cache..."
apt-get update -qq

# ─────────────────────────────────────────────────────────────────────────────
# 1. git
# ─────────────────────────────────────────────────────────────────────────────
if is_installed git; then
  success "git already installed: $(git --version)"
else
  info "Installing git..."
  apt-get install -y -qq git
  success "git installed: $(git --version)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. python3
# ─────────────────────────────────────────────────────────────────────────────
if is_installed python3; then
  success "python3 already installed: $(python3 --version)"
else
  info "Installing python3..."
  apt-get install -y -qq python3 python3-pip
  success "python3 installed: $(python3 --version)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. jq
# ─────────────────────────────────────────────────────────────────────────────
if is_installed jq; then
  success "jq already installed: $(jq --version)"
else
  info "Installing jq..."
  apt-get install -y -qq jq
  success "jq installed: $(jq --version)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. AWS CLI v2
# ─────────────────────────────────────────────────────────────────────────────
if is_installed aws; then
  success "AWS CLI already installed: $(aws --version)"
else
  info "Installing AWS CLI v2..."
  apt-get install -y -qq unzip curl
  TMP_DIR=$(mktemp -d)
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${TMP_DIR}/awscliv2.zip"
  unzip -q "${TMP_DIR}/awscliv2.zip" -d "${TMP_DIR}"
  "${TMP_DIR}/aws/install" --update
  rm -rf "${TMP_DIR}"
  success "AWS CLI installed: $(aws --version)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. kubectl
# ─────────────────────────────────────────────────────────────────────────────
if is_installed kubectl; then
  success "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  info "Installing kubectl (latest stable)..."
  KUBECTL_VERSION=$(curl -fsSL "https://dl.k8s.io/release/stable.txt")
  curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl
  chmod +x /usr/local/bin/kubectl
  success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. Terraform
# ─────────────────────────────────────────────────────────────────────────────
if is_installed terraform; then
  success "Terraform already installed: $(terraform version -json | jq -r '.terraform_version')"
else
  info "Installing Terraform (HashiCorp apt repo)..."
  apt-get install -y -qq gnupg software-properties-common curl

  # Import HashiCorp GPG key using the modern apt keyring approach
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

  apt-get update -qq
  apt-get install -y -qq terraform
  success "Terraform installed: $(terraform version -json | jq -r '.terraform_version')"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 7. Helm
# ─────────────────────────────────────────────────────────────────────────────
if is_installed helm; then
  success "Helm already installed: $(helm version --short)"
else
  info "Installing Helm (official installer)..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | bash
  success "Helm installed: $(helm version --short)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 8. Ansible  (control machine for the GitLab runbook — needs 2.15+ / py3.9+)
# ─────────────────────────────────────────────────────────────────────────────
if is_installed ansible; then
  success "Ansible already installed: $(ansible --version | head -n1)"
else
  info "Installing Ansible (official Ansible PPA)..."
  # software-properties-common provides add-apt-repository (also pulled in by Terraform)
  apt-get install -y -qq software-properties-common

  # Add the upstream Ansible PPA so we get a current ansible-core, not the
  # older version shipped in the Ubuntu 22.04 universe repo.
  add-apt-repository --yes --update ppa:ansible/ansible
  apt-get install -y -qq ansible
  success "Ansible installed: $(ansible --version | head -n1)"
fi

# Galaxy collections required by the GitLab runbook. Installed to a system-wide
# path so they're available no matter which user runs the playbook.
if [[ -f "${ANSIBLE_REQUIREMENTS}" ]]; then
  info "Installing Galaxy collections from ${ANSIBLE_REQUIREMENTS}..."
  ansible-galaxy collection install -r "${ANSIBLE_REQUIREMENTS}" \
    -p "${ANSIBLE_COLLECTIONS_PATH}"
  success "Galaxy collections installed to ${ANSIBLE_COLLECTIONS_PATH}"
else
  warn "Requirements file not found at ${ANSIBLE_REQUIREMENTS} — skipping Galaxy collections."
  warn "Run later with: ansible-galaxy collection install -r <repo>/gitlab-ansible/requirements.yml"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}All tools are installed and ready.${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  %-12s %s\n" "git"       "$(git --version)"
printf "  %-12s %s\n" "python3"   "$(python3 --version)"
printf "  %-12s %s\n" "jq"        "$(jq --version)"
printf "  %-12s %s\n" "aws"       "$(aws --version)"
printf "  %-12s %s\n" "kubectl"   "$(kubectl version --client --short 2>/dev/null || kubectl version --client)"
printf "  %-12s %s\n" "terraform" "$(terraform version -json | jq -r '.terraform_version')"
printf "  %-12s %s\n" "helm"      "$(helm version --short)"
printf "  %-12s %s\n" "ansible"   "$(ansible --version | head -n1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

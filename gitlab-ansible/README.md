# GitLab Self-Hosted on EC2 — Ansible Runbooks

Ansible playbooks and roles for installing and configuring a self-hosted GitLab instance on an AWS EC2 instance using the official GitLab Omnibus package.

---

## Directory Structure

```
gitlab-ansible/
├── ansible.cfg                        # Ansible configuration
├── requirements.yml                   # Galaxy collection dependencies
├── inventory/
│   └── hosts.yml                      # EC2 target host(s)
├── group_vars/
│   └── gitlab.yml                     # GitLab configuration variables
├── playbooks/
│   └── install.yml                    # Full install + configure
└── roles/
    ├── gitlab_install/                # Installs GitLab Omnibus package
    └── gitlab_configure/              # Renders gitlab.rb and reconfigures
```

---

## Prerequisites

### Control machine

- Python 3.9+
- Ansible 2.15+

```bash
pip install ansible
ansible-galaxy collection install -r requirements.yml
```

### EC2 instance

- Ubuntu 24.04 LTS (or Amazon Linux 2023 — set `ansible_user: ec2-user`)
- Minimum: **4 vCPU / 8 GB RAM** (t3.xlarge recommended)
- Minimum: **50 GB** gp3 root EBS volume
- Security group inbound: TCP 22, 80, 443, 2222
- SSH key pair available locally

---

## Quick Start

### 1. Configure inventory

Edit `inventory/hosts.yml`:

```yaml
gitlab_server:
  ansible_host: 1.2.3.4                        # your EC2 IP or DNS
  ansible_user: ubuntu
  ansible_ssh_private_key_file: ~/.ssh/gitlab-ec2.pem
```

### 2. Set variables

Edit `group_vars/gitlab.yml`:

```yaml
gitlab_external_url: "https://gitlab.example.com"
gitlab_letsencrypt_email: "admin@example.com"
```

For sensitive values use Ansible Vault:

```bash
ansible-vault encrypt_string 'my-secret' --name 'gitlab_smtp_password'
```

### 3. Run the playbook

SSH into the EC2 instance, clone this repo, then run:

```bash
ansible-playbook playbooks/install.yml
```

With Vault:

```bash
ansible-playbook playbooks/install.yml --ask-vault-pass
```

After the run completes, the initial root password is at `/etc/gitlab/initial_root_password` on the server. It is deleted after 24 hours — **change it immediately**.

---

## SSL Modes

Set `gitlab_ssl_mode` in `group_vars/gitlab.yml`:

| Mode | Description |
|---|---|
| `letsencrypt` | Auto-provision and renew via Let's Encrypt (requires public DNS + port 80 open) |
| `self_signed` | Use a self-signed certificate (add cert paths in `gitlab.rb.j2`) |
| `custom` | Bring your own certificate (configure nginx manually in `gitlab.rb.j2`) |

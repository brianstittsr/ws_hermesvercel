# GitHub Integration Skill for Hermes
# Automated GitHub repository management via Telegram

name: github-integration
description: "Automated GitHub repository updates and management via Telegram"
version: "1.0.0"

# Telegram trigger configuration
triggers:
  - type: telegram
    bot_token: ${TELEGRAM_BOT_TOKEN}
    commands:
      - "/github-update" - Update specified repository
      - "/github-status" - Check repository status
      - "/github-branch" - Create or switch branches
      - "/github-pr" - Create pull request
      - "/github-deploy" - Deploy changes

# GitHub configuration
github:
  token: ${GITHUB_TOKEN}
  username: ${GITHUB_USERNAME}
  default_branch: ${GITHUB_DEFAULT_BRANCH:-main}
  repositories: ${GITHUB_REPOS}

# Available actions
actions:
  - name: update-repository
    description: "Update repository with Codex-generated changes"
    steps:
      - clone-repository
      - analyze-changes
      - generate-updates
      - commit-changes
      - push-to-github

  - name: create-branch
    description: "Create new branch for feature development"
    steps:
      - checkout-default-branch
      - create-feature-branch
      - setup-branch-protection

  - name: create-pull-request
    description: "Create pull request with generated changes"
    steps:
      - prepare-pr-description
      - create-pull-request
      - assign-reviewers
      - set-labels

  - name: deploy-changes
    description: "Deploy changes to production"
    steps:
      - run-tests
      - build-project
      - deploy-to-environment
      - verify-deployment

# Codex integration
codex:
  model: gpt-5.4
  instructions: |
    You are a GitHub automation assistant. When asked to update repositories:
    1. Analyze the repository structure and existing code
    2. Generate high-quality, well-documented code changes
    3. Follow the project's coding standards and conventions
    4. Create meaningful commit messages
    5. Ensure all changes are tested before committing

# Security considerations
security:
  - never expose GitHub tokens in logs
  - validate all repository access permissions
  - require approval for destructive operations
  - maintain audit log of all GitHub operations
  - limit repository access to configured repos only

# Error handling
error_handling:
  - retry-on-failure: 3
  - notify-on-error: true
  - rollback-on-failure: true
  - log-all-operations: true

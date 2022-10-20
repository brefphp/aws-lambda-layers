## Setup

### 1. Authorize GitHub Actions to deploy to AWS

In order to let GitHub Actions upload layers to AWS, we authorize GitHub via [OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) instead of hardcoded AWS access keys.

This needs to be done once in the AWS console (because no access keys have permissions to deploy via CloudFormation).

- file: `github-role.yml`
- stack name: github-oidc-provider
- `FullRepoName` parameter: `brefphp/aws-lambda-layers`

### 1. (old) Create the role in the "layers" account

This needs to be done once in the AWS console (because no access keys have permissions to deploy via CloudFormation).

- file: `role.yml`
- stack name: layers-builder-role
- `BuilderAccount` parameter: `416566615250` in my case (edit as necessary)

Change the `--profile` argument to the profile you want to use.

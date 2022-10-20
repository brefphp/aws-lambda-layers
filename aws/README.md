## Setup

### 1. Create the role in the "layers" account

This needs to be done once in the AWS console because no access keys have permissions to deploy via CloudFormation.

- file: `role.yml`
- stack name: layers-builder-role
- `BuilderAccount` parameter: `416566615250` in my case (edit as necessary)

Change the `--profile` argument to the profile you want to use.

### 2. Deploy the pipeline in the "builder" account

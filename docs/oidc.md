# Giving GitHub Actions access to AWS without a stored key

`.github/workflows/plan.yml` needs AWS credentials. The wrong way to supply
them is an access key pasted into repository secrets: it is long-lived, it is
copied wherever the repository is forked or cloned, and revoking it means
finding every place it was reused.

The right way is a trust relationship. GitHub mints a short-lived OIDC token
that says which repository, which branch and which workflow is running. AWS is
configured to trust that issuer and to hand back temporary credentials only to
a request carrying a token that matches conditions you set. Nothing is stored.

## Register GitHub as an identity provider

Once per AWS account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com
```

## Create the role

The trust policy is where the security actually lives. The `sub` condition is
what stops any other repository on GitHub from assuming this role.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:ibrahimjamli/terraform-aws-webstack:*"
      }
    }
  }]
}
```

Narrow that `sub` further where you can. `repo:owner/name:ref:refs/heads/main`
restricts it to the default branch, and
`repo:owner/name:environment:production` restricts it to a job running in a
protected environment. A trailing `:*` permits any branch in the repository,
including one opened by a pull request, which is fine for a plan-only role and
not fine for one that can apply.

## Attach permissions

The plan job only reads. Attach `ReadOnlyAccess` plus write access to the state
bucket and lock table:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::webstack-tfstate-<ACCOUNT_ID>",
        "arn:aws:s3:::webstack-tfstate-<ACCOUNT_ID>/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:*:<ACCOUNT_ID>:table/webstack-tfstate-locks"
    }
  ]
}
```

A role that can apply needs more, and should be a separate role restricted to
the default branch and to a protected environment, so a pull request from a
fork cannot reach it.

## Point the workflow at it

Set these as repository variables, not secrets. A role ARN is not a credential
and treating it as one only makes it harder to audit.

| Variable | Example |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/gha-webstack-plan` |
| `AWS_REGION` | `eu-north-1` |
| `TF_STATE_BUCKET` | `webstack-tfstate-123456789012` |
| `TF_LOCK_TABLE` | `webstack-tfstate-locks` |

```bash
gh variable set AWS_ROLE_ARN --body "arn:aws:iam::123456789012:role/gha-webstack-plan"
```

The workflow is guarded on `vars.AWS_ROLE_ARN != ''`, so until this is set the
job is skipped rather than failed.

## Checking it works

Open a pull request touching anything under `modules/` or `envs/`. The plan job
should assume the role, run, and post the plan as a comment. If it fails at the
assume-role step, the `sub` condition and the workflow's actual
`repo:owner/name:...` value disagree; the error message names the value that
was presented, which is usually enough to spot the mismatch.

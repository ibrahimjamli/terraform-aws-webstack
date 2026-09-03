# terraform-aws-webstack

[![CI](https://github.com/ibrahimjamli/terraform-aws-webstack/actions/workflows/ci.yml/badge.svg)](https://github.com/ibrahimjamli/terraform-aws-webstack/actions/workflows/ci.yml)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.9-7B42BC)](https://developer.hashicorp.com/terraform)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A three-tier AWS web stack built as reusable Terraform modules: a VPC with
public and private subnets, an auto scaling group behind an application load
balancer, and S3 storage with the controls AWS leaves off by default.

The pipeline runs 22 unit tests, a linter, a policy scanner, and a genuine
`terraform apply` against a LocalStack container on every push. None of it
needs an AWS account, and none of it costs anything.

---

## What is here

```
modules/
  network/    VPC, subnets, routing, NAT, flow logs
  security/   security groups for the load balancer and app tiers
  compute/    launch template, auto scaling group, load balancer, IAM
  storage/    S3 with encryption, versioning, lifecycle and TLS-only access
envs/
  dev/        composes the modules into a working environment
  localstack/ the subset CI can really apply, for pipeline verification
bootstrap/    S3 state bucket and DynamoDB lock table, run once per account
```

Modules hold the logic. Environments only decide how big, how many and how
expensive.

## What the pipeline checks

| Job | Tool | What it catches |
|---|---|---|
| Format | `terraform fmt` | Unformatted configuration |
| Validate | `terraform validate` | Type errors and bad references, in all 7 directories |
| Lint | tflint | Invalid instance types, undocumented variables, dead declarations |
| Policy | Checkov | Unencrypted storage, public buckets, permissive security groups |
| Unit tests | `terraform test` | 22 assertions about what the modules actually plan |
| LocalStack | real `apply` | Dependency ordering, and resources read back from an API |
| Idempotence | second `plan` | Configuration that recreates something on every run |

### Why LocalStack rather than just `validate`

`terraform validate` checks that the configuration parses and type-checks. It
does not make a single API call, so it cannot tell you that a resource was
created in the wrong order, that an argument the provider accepts is rejected
by the service, or that the thing you asked for is not the thing you got.

The CI job runs `terraform apply` against a LocalStack container, then queries
the resulting resources with the AWS CLI and asserts on what comes back: the
VPC has the CIDR it should, there are four subnets, no private subnet
auto-assigns public addresses, the bucket has versioning on and public access
blocked. Then it plans again and fails if the second plan is not empty.

That last check is scoped to the network and storage modules. LocalStack does
not round-trip security group rules faithfully: it returns the referenced group
id account-prefixed and drops the rule description, so a second plan reports an
in-place update that real AWS would not. Narrowing the check keeps it
meaningful; deleting it would not.

**What LocalStack's free tier does not emulate**, and which this pipeline
therefore does not claim to prove: the application load balancer, the auto
scaling group, and NAT gateways. S3 lifecycle configuration is a subtler case,
it accepts the call and then never returns the configuration, so the provider's
read-back poll times out after three minutes; the LocalStack environment turns
that one resource off. All of it is covered by `validate`, the unit tests and
the policy scan instead. Reporting them as verified would be a green tick that
means nothing.

An [architecture diagram](docs/architecture.md) shows the traffic path, the
module dependencies and, in a table, exactly which components each check
covers.

## Design notes

**No SSH anywhere.** There is no key pair, no bastion and no port 22 rule. The
instance role carries `AmazonSSMManagedInstanceCore`, so shell access goes
through Session Manager, which is audited and needs no inbound port.

**IMDSv2 is required, not merely available.** `http_tokens = "required"` is
what stops a server-side request forgery bug in the application from being
turned into instance credentials. Several well-known cloud breaches worked
exactly that way.

**Security group rules are separate resources.** Inline `ingress` blocks are
authoritative for the entire group, so two modules touching one group silently
delete each other's rules. The `aws_vpc_security_group_*_rule` resources do
not have that failure mode.

**The app tier references the load balancer's security group, not a CIDR.**
The rule stays correct however the load balancer's addresses change, and there
is a test asserting no address-range rule ever appears on that group.

**The default security group is emptied.** AWS creates one that allows all
traffic between its members and it cannot be deleted, so it is explicitly
managed and left with no rules.

**Cross-variable validation.** `public_subnet_cidrs` must have one entry per
availability zone. Written as a resource precondition, a mismatch surfaces as
an index-out-of-range error pointing at a subnet. Written as a variable
validation, which Terraform 1.9 permits, it fails immediately with a sentence
that says what to fix.

**State is bucketed, versioned, locked and undeletable.** `bootstrap/` creates
the state bucket with `prevent_destroy`, versioning and a TLS-only policy, plus
a DynamoDB lock table. Two people running apply at the same time without a lock
corrupt the state, and it is usually noticed much later.

**Every Checkov skip names its reason.** An unexplained suppression is how a
security baseline quietly stops meaning anything. See [.checkov.yml](.checkov.yml).

## Running it

### The tests, which need nothing

```bash
make test
```

Every test uses `command = plan`, so there is no AWS account, no credentials
and no cost. The suite finishes in seconds.

### Against LocalStack

```bash
make localstack-up
make localstack-test
make localstack-down
```

### Against a real AWS account

Create the state backend once:

```bash
terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply
```

That prints the exact `init` command for the environments. Then:

```bash
cd envs/dev
terraform init -backend-config="bucket=..." -backend-config="key=webstack/dev/terraform.tfstate"
terraform plan
```

`envs/dev` costs roughly 40 to 60 EUR a month if left running, most of it the
NAT gateway and the load balancer. `terraform destroy` removes all of it.

`make help` lists every target.

## Enabling plan-on-pull-request

[`.github/workflows/plan.yml`](.github/workflows/plan.yml) runs `terraform
plan` against a real account and posts the result as a pull-request comment,
updating one comment in place rather than accumulating stale plans.

It is dormant until the repository variable `AWS_ROLE_ARN` is set, so a clone
without AWS access gets a skipped job rather than a red cross. Credentials come
from GitHub's OIDC provider and are minted per run, so no long-lived access key
is ever stored in the repository.

## License

MIT. See [LICENSE](LICENSE).

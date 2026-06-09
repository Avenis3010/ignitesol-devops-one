# 1. Secure Secret Management Using External Secrets Operator.
  Previosuly, secrets were created directly from CI/CD pipelines using commands such as:
  - kubectl create secret

## This approach introduced several challenges:
1. Sensitive values existed within GitHub Secrets.
2. Secrets could accidentally appear in pipeline logs.
3. Secret rotation required workflow modifications.
4. Secret lifecycle management was difficult.
    
## Changes Made:
To solve these issues, I implemented External Secrets Operator (ESO).
The new process works as follows:
1. Terraform provisions secrets into AWS Secrets Manager.
2. External Secrets Operator monitors configured secret definitions.
3. ESO securely retrieves secret values from AWS Secrets Manager.
4. Kubernetes secrets are generated automatically inside the cluster.
#### File reference: ignitesol-devops-one\terraform\modules\eso_irsa\main.tf
    
## Steps followed to change:
1. Added a secret module in Terraform and  remove the hardcoded db_password   from tfvars.
2. created Kubernetes external secret operator( per namespace for dev and prod)
3. Replace hardcoded secret.yaml files with ESO references
4. Remove hardcoded secret creation from dev and prod pipeline; ESO syncs it from Secrets Manager.
5. Apply ESO service account and SecretStore before running migration in dev and prod pipeline.

## Improvements Made:
1. At no point does the CI/CD pipeline directly handle database passwords or other sensitive values.
2. Now After that, the pipelines and ArgoCD handle everything automatically — no credentials ever touch Git or GitHub Secrets.
    
## Why This Change Was Necessary :
1. Security: The previous solution increased the risk of credential leakage and complicated secret management.

# 2. Implementation of Least Privilege IAM Roles
Initially, all GitHub workflows used a common AWS role with broad administrative permissions. 
If one workflow gets compromised: Attacker gains entire AWS access.
They can:  Delete production resources , Modify infrastructure ,Access secrets , push images.

## Steps followed to change:
1. Replaced the github oidc role  to least privillege IAM roles for backend, frontend and database for dev and prod env.
2. cloudfront permissions: Needed because after deployment: Users should see latest website. Old files cached. Pipeline executes: cloudfront:CreateInvalidation, This clears cache.
3. Gives resource specific permissions for not to Access every repository.
#### File reference: ignitesol-devops-one\terraform\modules\iam\main.tf

## Improvements Made:
1. Security reviews become easier because permissions are scoped to business    functions.
2. Access boundaries are clearly defined .
3. Test pipelines cannot accidentally destroy infrastructure.

# 3. Environment Isolation and Repeatable Deployments .
Initially had the shared resources for dev and prod env. 
1. Shared terraform state, shared netwrok, shared cluster
2. If someone manually run terraform apply in wrong workspace, this Production      resources could be modified. 

## Steps followed to change:
1.  Instead of one large cluster, we used Terraform to provision two completely independent stacks: envs/dev and envs/prod. 
2.  Implemented physical isolation by creating separate VPCs and EKS clusters for Dev and Prod.Each environment has its own RDS instance, S3 bucket, and ECR repository. 
3. Separate Terraform State: To prevent State Corruption, where a change in one environment accidentally modifies resources in another. we separated the Terraform State files. Each environment has its own terraform.tfstate key in the S3 backend. This allows to run terraform apply on Dev with zero risk of touching Production state.
4. Keyless CI/CD Roles (OIDC & Least Privilege): moved away from static AWS Access Keys to GitHub OIDC Federation. 
5. created scoped IAM roles like backend-dev-role and backend-prod-role. These roles use Trust Policies that are branch-locked: the Prod role can only be assumed by a workflow running on the production branch.
6. Production Protection (Manual Approval): Integrated GitHub Environments into the CI/CD pipelines.In the pipeline-prod.yaml, every deployment job is tied to a specific GitHub Environment (e.g., prod-backend). This environment is configured with Required Reviewers, so even if code is merged to the production branch, the actual deployment to AWS is paused until a senior engineer manually approves it in the GitHub UI.
7. Deployment Target Isolation:  To prevent 'Accidental Deployment' (deploying dev code to prod), we isolated the deployment targets in our GitHub Actions. The Dev pipeline is hard-coded to only talk to the central-platform-dev-eks cluster, while the Prod pipeline only targets central-platform-prod-eks.
8. ArgoCD AppProject Separation: The prod AppProject is restricted to only deploy to the prod namespace. It also includes a clusterResourceBlacklist for dangerous resources like Nodes or ClusterRoles. This ensures that even if someone accidentally changes a destination in a Helm chart, ArgoCD will block the sync because it violates the project's security policy.
9. Network Policy (Zero-Trust Networking): Applied Kubernetes NetworkPolicy to prevent cross-namespace communication.Applied a policy that uses namespaceSelector to block all traffic between the dev and prod namespaces. if a developer's pod in the dev namespace is compromised, the attacker cannot reach any services running in the production namespace.
#### File Reference: terraform/modules/iam/main.tf
#### File reference: ignitesol-devops-one\.github\workflows\pipeline-dev.yaml, ignitesol-devops-one\.github\workflows\pipeline-prod.yaml, argocd/project-prod.yaml, 
#### File reference: ignitesol-devops-one\.github\workflows\pipeline-dev.yaml, ignitesol-devops-one\.github\workflows\pipeline-prod.yaml, argocd/project-prod.yaml, 
#### File Reference: k8s/dev/network-policy.yaml, k8s/prod/network-policy.yaml

# 4. Make it clear what version is running, who deployed it, when it was deployed, and to which environment.
By default, Kubernetes doesn't provide enough deployment context such as who deployed the application, when it was deployed, or which code version is running. Without this information, troubleshooting requires manually matching container images in ECR with GitHub commits, which slows down incident investigation.

## Steps followed to change:
1. Deployment metadata.labels — added app.kubernetes.io/version (image tag) and app.kubernetes.io/environment
2. Deployment metadata.annotations — added 6 audit annotations: deploy/git-sha, deploy/git-ref, deploy/deployed-by, deploy/deploy-time, deploy/image-tag, deploy/environment
3. Pod template gets the same labels + annotations so both kubectl describe deployment and kubectl describe pod show audit info.
4. image reference changed from {{ .Values.image.tag | default .Chart.AppVersion }} to {{ .Values.image.tag }} — removes the :latest fallback entirely
5. The commit step now writes all 5 audit fields into the values file before committing, so ArgoCD picks them up via GitOps — no --set needed at sync time.
#### File Reference: values-dev.yaml + values-prod.yaml, deployment.yaml

## The Metadata Flow:

1. CI Trigger: A developer pushes code to dev or production.
2. Metadata Capture: The pipeline captures $GITHUB_SHA (version), $GITHUB_ACTOR (who), and the current timestamp (when).
3. Git Injection: The pipeline uses sed to update the audit block in the environment-specific values.yaml file and commits it back to the repository.
4. ArgoCD Sync: ArgoCD detects the change in Git and synchronizes the cluster.
5. K8s Manifestation: The Helm chart maps these values to Kubernetes Labels, Annotations, and Environment Variables.
#### File reference:  .github/workflows/pipeline-dev.yaml, .github/workflows/pipeline-prod.yaml

## ImprovementS Made:
1. By running kubectl describe deployment <name>, any authorized user can instantly see the Git SHA, the branch, the person who triggered the deploy, and the exact time it occurred.
2. This automates the audit trail. No human intervention is required to record who deployed the code, reducing the risk of missing or incorrect logs.

# 5. Repeatable Environment Provisioning from Code
Initially, Terraform was only creating the AWS infrastructure like VPC, EKS, and RDS. After the cluster was created, engineers still had to manually install tools such as ArgoCD, Ingress Controllers, and monitoring components using Helm commands. This meant the cluster was not fully ready to use immediately and required additional manual setup.

## Steps followed to change:
1. Updated Terraform so it can connect to the EKS cluster automatically. Earlier, we had to manually configure kubeconfig before deploying anything inside the cluster. Now Terraform handles it automatically.
2. created a Terraform module that automatically installs important tools like ArgoCD, External Secrets Operator, AWS Load Balancer Controller, after the cluster is created. Earlier, these tools had to be installed manually using Helm commands.
3. Connected all these modules to both the Dev and Production environments. Now a complete environment can be created or recreated using a single Terraform command without any manual setup.
#### File reference: terraform/modules/bootstrap/main.tf, terraform/envs/dev/providers.tf

## Improvements Made:
1. Now, when we run terraform apply, the complete environment is created automatically. The cluster, platform tools, namespaces, and configurations are all set up without needing any manual Helm or kubectl commands.
2. fixed the versions of important tools like ArgoCD and External Secrets Operator in the Terraform code. This ensures that Dev and Production always use the same versions and configurations, avoiding issues caused by version differences.
3. Since everything is defined in code and stored in the repository, we can quickly rebuild the entire environment if needed. Whether it's a new AWS account, region, or a disaster recovery scenario, the same setup can be recreated in a short time using Terraform.

## Why This Change Was Necessary:
1. When people do things manually, mistakes can happen and environments can become different. By keeping everything in code, we make sure Dev and Production are set up the same way every time.


# 6. ArgoCD Project Isolation & Branch Protection
Initially, all applications were deployed using the default ArgoCD project, which had no restrictions. Applications could potentially be deployed to any namespace or create any resource. Also, there were no branch protection rules, so code could be pushed directly to important branches without review or testing.

## Steps followed to change:
1. Created separate ArgoCD projects "project-dev.yaml" and "project-prod.yaml" for Dev and Production. This ensures that Dev applications cannot accidentally deploy to the Production namespace.
2. Implemented a clusterResourceBlacklist in both projects. This prevents applications from accidentally modifying Nodes, PersistentVolumes, or Cluster-wide RBAC roles.
3.Configured syncWindows for the production project. Automated syncs are only allowed during business hours with a full deny on weekends.
4. Disabled automated sync in "backend-prod.yaml". The production pipeline now explicitly triggers a sync only after a manual approval gate is cleared in GitHub Actions.
5. Implemented a new ci-checks.yaml workflow that runs on every Pull Request. We then configured GitHub Branch Protection rules requiring:
   - A Pull Request with at least 2 approvals for production.
   - Mandatory "Status Checks" (Linting, Docker Build dry-run, and Helm Chart validation) to pass before merging.
6. Added concurrency groups to the main pipelines to ensure that only one deployment runs at a time per environment. This prevents multiple deployments from interfering with each other and avoids deployment conflicts.
#### File reference: argocd/project-prod.yaml, .github/workflows/ci-checks.yamL

## Improvements Made:
1. Blast Radius Control: Even if a developer accidentally points a dev Helm chart to the production namespace, ArgoCD will reject the sync because it violates the AppProject security policy.
2. Drift Detection:ArgoCD now alerts if any resource exists in the dev or prod namespaces that isn't explicitly defined in Git, catching manual "hotfixes.
3. Branch protection ensures that no code reaches production without human approval.
4. Ensure that if multiple PRs are merged in quick succession, the deployments happen in order, maintaining the integrity of the environment state.

## Why This Change Was Necessary:
1. Human Error: In a environment, the risk of a "wrong branch" or "wrong namespace" deployment is high. These provide the safety needed to move fast without breaking production.
2. Availability:Maintenance windows and mandatory PR reviews ensure that changes to production are intentional, documented, and performed when support staff are available.

# 7. Security Scanning & Code Quality Gates
Initially, the platform relied on manual code reviews to catch security issues or bugs. There was no automated process to scan for known vulnerabilities in container images or third-party dependencies, and no mechanism to detect hardcoded secrets before they were merged into the repository.

## Steps followed to change:
1. SonarQube Integration: Integrated a SonarQube Quality Gate into the "ci-checks.yaml" workflow. It analyzes the code for bugs, code smells, and vulnerabilities, and enforces a "Passed" status before a Pull Request can be merged.
2. Trivy Filesystem Scanning: Added an automated filesystem scan in the CI phase to detect hardcoded secrets and high-risk vulnerabilities in the source code and its requirements.txt dependencies.
3. Trivy Image Scanning: Updated both "pipeline-dev.yaml" and "pipeline-prod.yaml" to include a container image scan. The pipeline now builds the image locally, scans it, and blocks the push to ECR if vulnerabilities are found.
4. Environment-Specific Thresholds:
    - Dev:  Blocks deployment on CRITICAL vulnerabilities.
    - Prod: Blocks deployment on both CRITICAL and HIGH vulnerabilities.
#### File reference: .github/workflows/ci-checks.yaml, .github/workflows/pipeline-prod.yaml

## Improvements Made:
1. Automated Blocking: The pipelines now physically prevent insecure code or images from reaching the ECR registry or the EKS cluster.
2. Security findings are centralized in the GitHub Security dashboard, making it easy for engineers to track and remediate vulnerabilities without leaving the development environment.


## Why This Change Was Necessary:
1. Proactive Security: Discovering a vulnerability in a production container is expensive and risky. Identifying it during the build phase allows for immediate remediation at almost zero cost.


# 8. Resource Limits & Horizontal Pod Autoscaling
Initially, the containers did not have CPU or memory limits configured. This meant that if one application started using too many resources, it could affect other applications running on the same node.

## Steps followed to change:
1. Environment-Specific Sizing: Defined resource blocks in values-dev.yaml and values-prod.yaml. Development pods are given minimal cpu and memory limits (100m CPU / 128Mi RAM), while Production pods are allocated higher cpu and memory (200m CPU / 256Mi RAM).
2.Modified deployment.yaml to remove the {{- with .Values.resources }} conditional guard. This ensures that resource manifests are always rendered into the final Kubernetes object, preventing developers from accidentally deploying pods without limits.
3. Added CPU and memory limits to database migration jobs in both Dev and Production. Since these jobs run temporarily, they are restricted so they don’t affect the performance of running applications.
4. Enabled Horizontal Pod Autoscaling in Production. It automatically increases or decreases the number of pods based on CPU usage, with a target of 70%.
#### File reference: backend-services/users-api/backend-api/values-prod.yaml, backend-services/users-api/backend-api/templates/deployment.yaml

## Improvements Made:
1.Kubernetes now places pods more intelligently because it uses resource requests. This ensures pods are only scheduled on nodes that have enough available CPU and memory.
2. By setting limits, we ensure that a pod exceeding its memory allocation is OOMKilled by the kernel before it can crash the entire EC2 node.
3. HPA now scales applications more accurately because it uses resource requests as a baseline to measure CPU usage and decide when to add more pods.


## Why This Change Was Necessary:
1. Without resource limits, one failing application can overload the system and cause other services to fail. By adding limits, we ensure the backend API stays stable and responsive even during high traffic or unexpected spikes.


# 9. Pod and Container Level Security Hardening
Initially, containers were running with default permissions, which often include root execution and excessive Linux capabilities. This left the cluster vulnerable to container breakout attacks, where a compromised application could potentially gain control over the underlying host node or access sensitive data in other pods.

## Steps followed to change:
1. Enforced Non-Root Execution: Configured both Pod and Container security contexts to require "runAsNonRoot: true" and mapped execution to a specific non-privileged UID (1000).
2. Privilege Escalation Prevention: Set "allowPrivilegeEscalation: false" at the container level. This blocks processes from gaining more privileges than their parent process, effectively neutralizing sudo and SUID-based attacks.
3. Enabled 'readOnlyRootFilesystem: true" for the API containers. This ensures that even if an attacker gains shell access, they cannot write malicious payloads, modify binaries, or change configuration files on the disk.
4. Implemented a "Drop ALL" policy for Linux capabilities. By removing standard but unnecessary capabilities like `NET_RAW` or `SYS_ADMIN`, we drastically reduce the kernel surface area available to an attacker.
5. Configured the `RuntimeDefault` seccomp profile. This instructs the container runtime (containerd/Docker) to use its default syscall filter, blocking hundreds of dangerous system calls that are not required for standard web applications.
#### File reference: backend-services/users-api/backend-api/templates/deployment.yaml, backend-services/users-api/backend-api/values.yaml

## Improvements Made:
1. By combining non-root users with read-only filesystems and dropped capabilities, we create multiple layers of security that an attacker must bypass.
2. The read-only root filesystem guarantees that the container remains in the exact state it was built in, simplifying forensics and preventing persistence after a compromise.
3. These settings align with the Kubernetes "Restricted" Pod Security Standard, which is a requirement for many security frameworks like SOC2 and PCI-DSS.
4. Using "fsGroup" ensures that even with non-root users, the application can still securely read and write to mounted volumes like ConfigMaps or temporary scratch space.

## Why This Change Was Necessary:
1. Vulnerabilities in application code (like a remote code execution bug) are inevitable. Hardening the pod ensures that even if the application is exploited, the attacker is "trapped" in a highly restricted, read-only environment with no path to escalate privileges to the host.
2. Preventing pods from running as root or having host-level capabilities protects the EKS nodes from accidental or malicious reconfiguration by a containerized process.

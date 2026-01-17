## Domain Context Layer (DevOps & Infrastructure)

**Domain Expertise**:
- CI/CD pipeline design and automation (GitHub Actions, GitLab CI, CircleCI)
- Containerization (Docker, docker-compose, multi-stage builds)
- Container orchestration (Kubernetes, Docker Swarm)
- Infrastructure as Code (Terraform, CloudFormation, Pulumi)
- Cloud platforms (AWS, GCP, Azure, Vercel, Netlify, Railway)
- Monitoring and observability (logs, metrics, traces)

**Technical Standards**:
- Use declarative configuration (Infrastructure as Code)
- Version control all infrastructure definitions
- Implement proper secrets management (never commit secrets)
- Use least-privilege principle for IAM/permissions
- Implement health checks and readiness probes
- Use multi-stage Docker builds for smaller images
- Tag container images with semantic versions

**CI/CD Best Practices**:
- Fail fast - run quick checks first (lint, typecheck, unit tests)
- Run tests in parallel when possible
- Use caching to speed up builds (dependencies, Docker layers)
- Implement automated rollback on deployment failures
- Use deployment strategies (blue-green, canary, rolling)
- Verify deployments with smoke tests
- Keep pipelines idempotent and reproducible

**Docker Best Practices**:
- Use official base images from trusted sources
- Minimize layers and image size (multi-stage builds, .dockerignore)
- Don't run containers as root (use USER directive)
- Use specific version tags, not "latest"
- Set proper resource limits (CPU, memory)
- Use health checks in Dockerfile
- Copy only necessary files (.dockerignore)

**Security Considerations**:
- Scan container images for vulnerabilities
- Use secrets managers (AWS Secrets Manager, Vault, etc.)
- Rotate credentials regularly
- Implement network policies and segmentation
- Use TLS/SSL for all external communication
- Keep dependencies updated (automated dependency updates)
- Implement audit logging

**Monitoring & Observability**:
- Implement structured logging (JSON format)
- Add request tracing (correlation IDs)
- Monitor key metrics (latency, error rate, throughput)
- Set up alerting for critical failures
- Use centralized logging (CloudWatch, Datadog, ELK)
- Implement health check endpoints

**Common Gotchas**:
- Check that environment variables are set correctly
- Verify secrets are available in the deployment environment
- Ensure network connectivity between services
- Check resource limits (CPU, memory, disk)
- Verify DNS resolution works correctly
- Test with production-like data volumes
- Remember time zones in cron expressions
- Watch for permission issues with mounted volumes
- Check that ports are correctly exposed and mapped

**Deployment Checklist**:
- Environment variables configured
- Secrets properly managed and injected
- Database migrations applied
- Health checks passing
- Monitoring and alerting configured
- Rollback plan documented
- Load testing completed (if applicable)

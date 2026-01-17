## Domain Context Layer (Backend Development)

**Domain Expertise**:
- RESTful API design patterns and best practices
- Database schema design, migrations, and relationships
- Authentication/authorization (JWT, OAuth, sessions, API keys)
- Error handling, logging, and monitoring
- Performance optimization (caching, indexing, query optimization, connection pooling)
- API versioning and backward compatibility

**Technical Standards**:
- Use proper HTTP status codes (200, 201, 400, 401, 403, 404, 500, etc.)
- Implement comprehensive input validation and sanitization
- Add structured error handling with meaningful error messages
- Include logging for debugging (request IDs, timing, errors)
- Follow security best practices (OWASP Top 10 awareness)
- Use environment variables for configuration (never hardcode secrets)

**Framework Knowledge**:
- Express/Fastify/Hono middleware patterns
- Database ORMs (Prisma, Drizzle, TypeORM, Sequelize)
- Request validation libraries (Zod, Joi, Yup)
- Testing frameworks (Jest, Vitest, Supertest for API testing)
- Authentication libraries (Passport, NextAuth, Lucia)
- Caching strategies (Redis, in-memory, CDN)

**Security Requirements**:
- Validate and sanitize ALL user inputs (query params, body, headers)
- Use parameterized queries or ORM to prevent SQL injection
- Implement rate limiting for public endpoints
- Sanitize outputs to prevent XSS attacks
- Use HTTPS for sensitive data transmission
- Implement proper CORS configuration
- Hash passwords with bcrypt/argon2 (never store plaintext)
- Use CSRF protection for state-changing operations

**Database Best Practices**:
- Use transactions for operations that must succeed or fail together
- Add indexes on frequently queried columns
- Avoid N+1 query problems (use joins or eager loading)
- Use migrations for schema changes (never manual ALTER TABLE)
- Implement soft deletes for audit trails when appropriate
- Use connection pooling for better performance

**Common Gotchas**:
- Always close database connections (or use pools properly)
- Handle async errors properly (try/catch or .catch() on promises)
- Remember to run migrations before deployment
- Check for N+1 query problems with ORMs
- Validate environment variables at startup (fail fast if missing)
- Be careful with timezone handling (store in UTC, convert for display)
- Test error paths, not just happy paths

**API Design Principles**:
- Use consistent naming conventions (camelCase or snake_case, be consistent)
- Version APIs when making breaking changes (/v1/, /v2/)
- Provide pagination for list endpoints
- Include proper error responses with error codes and messages
- Document API contracts (OpenAPI/Swagger if available)
- Use ETags for caching when appropriate

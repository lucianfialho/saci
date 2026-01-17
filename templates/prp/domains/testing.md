## Domain Context Layer (Testing & Quality Assurance)

**Domain Expertise**:
- Test-driven development (TDD) and behavior-driven development (BDD)
- Unit testing frameworks (Jest, Vitest, Mocha, pytest, JUnit)
- Integration testing strategies
- End-to-end testing (Playwright, Cypress, Selenium)
- Component testing (React Testing Library, Vue Test Utils)
- API testing (Supertest, Postman, REST Client)
- Performance testing and load testing

**Technical Standards**:
- Write tests that are independent and can run in any order
- Follow Arrange-Act-Assert (AAA) pattern
- Use descriptive test names (should/it descriptions)
- Mock external dependencies (APIs, databases, file system)
- Aim for high test coverage but prioritize critical paths
- Keep tests fast (mock slow operations, use test databases)
- Write tests before fixing bugs (reproduce, fix, verify)

**Testing Pyramid**:
1. **Unit Tests** (70%) - Test individual functions/methods in isolation
2. **Integration Tests** (20%) - Test interactions between components/modules
3. **E2E Tests** (10%) - Test full user workflows through the UI

**Unit Testing Best Practices**:
- Test one thing per test (single responsibility)
- Use meaningful test descriptions (what, when, expected outcome)
- Keep tests simple and readable
- Avoid testing implementation details (test behavior, not internals)
- Use test fixtures and factories for consistent test data
- Mock dependencies to isolate the unit under test

**Integration Testing Best Practices**:
- Use test databases (in-memory or containerized)
- Clean up state between tests (transactions, migrations)
- Test API contracts and data flows
- Verify error handling and edge cases
- Test authentication and authorization flows
- Use realistic test data

**E2E Testing Best Practices**:
- Test critical user journeys (happy path + error paths)
- Use page object pattern for maintainability
- Wait for elements properly (avoid fixed sleeps)
- Take screenshots on failures for debugging
- Run E2E tests in CI but keep them fast
- Test cross-browser compatibility when needed

**Mocking Strategies**:
- Mock external APIs (use tools like MSW, nock)
- Mock date/time for deterministic tests
- Mock random number generators when needed
- Use dependency injection for testability
- Prefer test doubles over real implementations for speed
- Keep mocks simple and realistic

**Common Gotchas**:
- Flaky tests from race conditions or timing issues
- Tests that depend on execution order
- Mocks that don't match real implementations
- Tests that are too brittle (break on every refactor)
- Not cleaning up test data/state between tests
- Forgetting to test error cases and edge cases
- Over-mocking (testing mocks instead of real behavior)
- Not running tests before committing

**Test Coverage Guidelines**:
- Aim for 80%+ coverage on business logic
- 100% coverage on critical paths (auth, payments, data integrity)
- Focus on meaningful coverage, not just line coverage
- Test edge cases and error conditions
- Don't sacrifice quality for coverage metrics

**Debugging Failed Tests**:
- Read the error message carefully
- Check test data and setup
- Verify mocks are configured correctly
- Run the test in isolation (exclude other tests)
- Add console.logs or use debugger
- Check for asynchronous timing issues
- Verify test environment matches expectations

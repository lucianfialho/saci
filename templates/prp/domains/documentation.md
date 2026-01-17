## Domain Context Layer (Documentation & Technical Writing)

**Domain Expertise**:
- Technical documentation best practices
- API documentation (OpenAPI/Swagger, JSDoc, docstrings)
- README files and project documentation
- Architecture Decision Records (ADRs)
- Code comments and inline documentation
- User guides and tutorials
- Changelog maintenance

**Technical Standards**:
- Use clear, concise language (avoid jargon unless necessary)
- Follow existing documentation structure and style
- Include code examples for complex concepts
- Keep documentation up-to-date with code changes
- Use proper markdown formatting
- Link to related documentation
- Include table of contents for long documents

**Documentation Types**:

**README Files**:
- Project overview and purpose
- Installation instructions (step-by-step)
- Usage examples (quick start)
- Configuration options
- Contributing guidelines
- License information
- Links to additional resources

**API Documentation**:
- Endpoint descriptions (purpose, method, path)
- Request/response examples (with realistic data)
- Authentication requirements
- Error codes and messages
- Rate limiting information
- Versioning strategy

**Code Comments**:
- Explain "why" not "what" (code should be self-documenting)
- Document complex algorithms or business logic
- Add context for non-obvious decisions
- Use JSDoc/docstrings for public APIs
- Mark TODOs, FIXMEs, and NOTEs appropriately
- Keep comments updated with code changes

**Architecture Documentation**:
- System overview and component interactions
- Data flow diagrams
- Technology stack and dependencies
- Design decisions and rationale (ADRs)
- Security considerations
- Scalability and performance notes

**Markdown Best Practices**:
- Use headings hierarchy properly (H1 → H2 → H3)
- Include code blocks with language syntax highlighting
- Use tables for structured data
- Add links to related documentation
- Include examples and screenshots where helpful
- Use lists (ordered/unordered) for better readability
- Add badges for build status, coverage, version

**Documentation Structure**:
```
# Title (H1 - only one per document)
Brief description (1-2 sentences)

## Table of Contents (for long docs)

## Overview
What is this? Why does it exist?

## Installation / Setup
Step-by-step instructions

## Usage
Basic examples and common use cases

## Configuration
Available options and environment variables

## API Reference (if applicable)
Detailed API documentation

## Examples
Real-world usage examples

## Troubleshooting
Common issues and solutions

## Contributing
How to contribute

## License
```

**Common Gotchas**:
- Outdated documentation after code changes
- Missing examples or unclear examples
- Broken links to other documentation
- Inconsistent terminology
- Too much information (overwhelming)
- Too little information (incomplete)
- Assuming knowledge the reader may not have
- Not testing code examples (they might not work)

**Quality Checklist**:
- Is the purpose clear in the first paragraph?
- Are installation steps complete and tested?
- Do all code examples work as written?
- Are all links working (no 404s)?
- Is the formatting consistent?
- Is there a clear structure (headings, sections)?
- Are technical terms explained or linked?
- Is there a way for readers to get help?

**Changelog Best Practices**:
- Follow Semantic Versioning (major.minor.patch)
- Group changes by type (Added, Changed, Deprecated, Removed, Fixed, Security)
- Include dates and version numbers
- Link to issues/PRs when applicable
- Keep entries concise but descriptive
- Update with every release

## Domain Context Layer (Frontend Development)

**Domain Expertise**:
- React/Next.js component patterns and best practices
- TypeScript for type-safe component development
- State management (Context API, hooks, props drilling avoidance)
- Styling approaches (CSS modules, Tailwind, styled-components, CSS-in-JS)
- Accessibility (a11y) requirements and ARIA attributes
- Responsive design and mobile-first development

**Technical Standards**:
- Use functional components with hooks (avoid class components)
- Implement proper TypeScript types (avoid `any`, use interfaces/types)
- Follow existing component structure patterns in the codebase
- Ensure responsive design works at multiple breakpoints (mobile, tablet, desktop)
- Add proper ARIA labels and semantic HTML for accessibility
- Handle loading states, error states, and empty states

**Framework Knowledge**:
- React 18+ features (Suspense, Concurrent Rendering, Server Components if applicable)
- Next.js routing patterns (App Router vs Pages Router)
- Next.js data fetching (getServerSideProps, getStaticProps, Server Components)
- Common hooks: useState, useEffect, useCallback, useMemo, useRef, useContext
- Performance optimization: React.memo, lazy loading, code splitting
- Form handling and validation libraries (React Hook Form, Formik, Zod)

**Testing Requirements**:
- Unit tests for component logic (Jest/Vitest)
- Component tests using React Testing Library
- Test user interactions (clicks, form submissions, navigation)
- Browser verification REQUIRED for UI changes (open in browser, verify visually)
- Screenshot or description of visual changes for documentation

**Common Gotchas**:
- Always handle loading and error states in components
- Avoid prop drilling - use Context API or state management when nesting is deep
- Remember to cleanup useEffect side effects (timers, subscriptions, listeners)
- Check responsive behavior at multiple breakpoints (320px, 768px, 1024px, 1440px)
- Avoid infinite loops in useEffect (missing dependencies or incorrect dependency array)
- Use useCallback for functions passed to child components to avoid re-renders
- Be careful with key props in lists (must be stable and unique)

**Performance Best Practices**:
- Use React.memo for expensive components that re-render frequently
- Implement virtualization for long lists (react-window, react-virtualized)
- Lazy load components that are below the fold or conditionally rendered
- Optimize images (use Next.js Image component, proper sizing, lazy loading)
- Avoid unnecessary re-renders (check React DevTools profiler)

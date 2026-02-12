# Team Decisions

> Shared brain — all decisions any agent makes, merged by Scribe

## Format

Each decision entry:

```
### YYYY-MM-DD: Decision title
**By:** {AgentName}
**What:** {Description of the decision}
**Why:** {Rationale}
```

---

### 2026-02-12: Project initialized
**By:** Squad (Coordinator)
**What:** Created team with 6 members – Suho (Lead), Mi (DevOps), Jisoo (Backend), Jennie (Tester), Rosé (Frontend), Lisa (DevRel)
**Why:** User requested custom team names for server process monitoring system with Salt Stack and Docker

### 2026-02-12: Repository integration strategy for process_monitor module

**By:** Suho

**What:** Analyzed 5 integration approaches (Git Submodule, Git Subtree, Direct Copy, Python Package, Monorepo) for incorporating process_monitor into another repository. Recommended Python Package approach as the primary strategy.

**Why:** 
- process_monitor is a self-contained, low-dependency tool (uses only Python standard library)
- Package approach provides clear boundaries, explicit version management, and easy reusability across multiple projects
- Enables simple installation via `pip install git+...` and straightforward updates with `pip install --upgrade`
- Python packages integrate naturally with Salt Stack environments (both Python-based)
- Allows independent development lifecycle while maintaining easy distribution
- Alternative approaches (Subtree, Monorepo) may be more suitable depending on target repository characteristics and team workflow

**Implementation notes:**
- Requires creating setup.py/pyproject.toml and restructuring as Python package
- Can be installed directly from Git URL with subdirectory specification
- Supports semantic versioning for stability guarantees

**Decision pending:** Final choice depends on target repository nature and whether ongoing synchronization with source repo is required

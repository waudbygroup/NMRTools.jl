# Contributing to NMRTools.jl

Thank you for your interest in contributing! This document covers how to report issues, propose changes, and submit pull requests.

## Getting started

1. Fork the repository and clone your fork.
2. Check out a new branch from `main` for your work.
3. Set up the development environment:
   ```julia
   ] dev .
   ```

## Reporting bugs and requesting features

Please open a [GitHub issue](https://github.com/waudbygroup/NMRTools.jl/issues) and include:

- Julia version (`julia --version`) and NMRTools.jl version.
- A minimal reproducible example, ideally using the bundled example data (`exampledata("2D_HN")`).
- For file-format bugs, attach or link to a small sample dataset if possible.

## Making changes

- Follow the style conventions in [CLAUDE.md](CLAUDE.md): lowercase public function names, CamelCase types, underscore-prefixed internal helpers.
- Use `im1` (not Julia's `im`) for the NMR complex unit.
- Add or update tests in `test/` to cover your changes.
- Run the test suite before opening a PR:
  ```julia
  julia -e 'using Pkg; Pkg.test()'
  ```
- Build the documentation locally to check for new warnings:
  ```julia
  julia make-local-docs.jl
  ```

## Pull requests

- Keep PRs focused — one logical change per PR.
- Write a clear description of what changed and why.
- Reference any related issues with `Fixes #N` or `Refs #N` in the PR body.
- CI must pass before merge.

## Questions

Feel free to open a discussion on GitHub or contact Chris at c.waudby@ucl.ac.uk.

## Code of conduct

All contributors are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

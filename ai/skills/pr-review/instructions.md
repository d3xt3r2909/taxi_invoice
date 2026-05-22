# PR Review

Use this workflow when asked to review a pull request, inspect a diff, or prepare review comments.

Start by understanding the stated goal of the change and the touched package boundaries. Inspect nearby tests and existing patterns before judging the implementation.

Focus review comments on concrete risks:

- correctness regressions
- security or privacy exposure, especially invoice/customer/recipient data
- missing or weak tests
- broken local architecture boundaries
- user-visible behavior changes
- PDF generation, printing, sharing, import, or export regressions
- maintainability problems that will make follow-up work harder

For each finding, explain the risk and suggest a practical fix. Avoid commenting on subjective style when the code follows local patterns.

Use `references/checklist.md` as the detailed checklist.

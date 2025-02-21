# ICON contribution guidelines

## Coding style

We use [`pre-commit`](https://pre-commit.com) hooks to maintain a set of
formatting and linting rules. Although there is a CI job that runs for each
merge request and checks whether the contribution does not break the rules, we
recommend registering the hooks in your local repository clone. This way, each
commit undergoes the formatting and linking checks automatically.

We recommend installing `pre-commit` to a separate Python virtual environment
using `pip`. For example, the following commands install the tool to the user's
home directory:
```bash
python3 -m venv ~/pre-commit
~/pre-commit/bin/python3 -m pip install --upgrade pip
~/pre-commit/bin/python3 -m pip install pre-commit
```

You can now switch to the root of the repository and run the following command
to register the hooks specified in
[`.pre-commit-config.yaml`](/.pre-commit-config.yaml):
```bash
cd icon
~/pre-commit/bin/pre-commit install
```

From now on, each commit you make will be checked by a set of formatters and
linters. Normally, the formatting tools are configured to modify the files in
place. This means that if they fail, all you need to do is to accept the
suggested changes and commit them:
```bash
git add .
git commit
```

Note that you will need to register the hooks for each fresh clone of the
repository. Alternatively, you can follow
[these instructions](https://pre-commit.com/#automatically-enabling-pre-commit-on-repositories)
to configure `git` to register hooks automatically for each new clone of a
repository that declares them.

## Issues

- Issues must be presented in a **clear way and provide all relevant information** so that other user can pick up.
- **Use issue** templates when creating issues, if available (e.g. for bugs).
- Issues must **address only one actionable task**. If an issue becomes too lengthy or complex, break it into smaller ones, link them to the original issue, and close the original.
- **Always** assign one person to each issue (communicate this clearly to the assigned person). When mentioning developers, include as many as necessary but as few as possible. TBD by owner (person who filed the ticket).

- Issues **do not need to have a milestone**, they can be standalone as long as they are classified with the appropiate labels.
- Use **as many labels as possible**, helps classifying issues. If there is no appropiate label, users are encouraged to create one. Labels can be projects (e.g. ~WarmWorld), machines (e.g. ~Levante), issue types (e.g. ~Discussion), etc.

- Issues to be **stalled after 2 months of inactivity** (new label for that), **closed after 2 months stalled**.


### Good habits

- **Have as much discussion as possible in the issues**. One of the aims of opening issues is that information is exchanged publicly and can be easily retrieved afterwards.
- **Tagging issues** (e.g. in MRs) helps showing activity in the issue and prevents them becoming stale. In addition, writing `Closes #<issue-ID>` in a MR automatically closes the issue when the MR is merged.
- We suggest to **not use tasks**, they enforce an additional level of hierarchy. To ease the workflow, we should use issues only.

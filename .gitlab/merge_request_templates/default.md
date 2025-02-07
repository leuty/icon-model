Make the merge request title concise. When the merge request is accepted, it
will become the first line of the commit message. Note that the message will
automatically get a repository-specific prefix (e.g. '[mpim] ', '[nwp] ', etc.).

### Short description

If the title is not enough to understand the main idea of the changes, provide a
short description, which will be appended to the merge request commit message.

Please, adhere to the following recommendations:
- use simple English in the active form (e.g. this implements A, updates B);
- keep it short, you are welcome to provide additional details below, in the
  respective section;
- avoid special Markdown symbols and prefer plain ASCII, the message should read
  well in the terminal;
- break the lines to make them no longer than 80 characters;
- do not reference issues and merge requests unless necessary;
    - if referencing is necessary, make sure the reference contains the name and
      the namespace of the respective repository, e.g. icon/icon#<issue-id> and
      icon/icon!<mr-id>.

The list of co-authors of the merge request is generated automatically based on
the authorship of the commits in the source branch. Please ensure that the
commits in the source branch have the correct authorship with the correct email
addresses (they can be "automatically-generated private commit emails"). If some
commits have the wrong authorship, you can provide the list of co-authors using
the following format (each entry on a separate line):
Co-authored-by: First-Name Second-Name <email.address@example.de>.

<------------------------ this is an 80-character line ------------------------>


### Detailed description (remove if unnecessary)

If necessary, provide a detailed explanation of the changes with plots,
formulas, links, etc.

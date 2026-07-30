## General

Do not truncate responses to the bare minimum. When answering a question, 
provide enough context and explanation for the answer to be fully understood.

Under no circumstances are you to make any edits or run any scripts until I 
explicitly say so. Acceptable confirmations are only direct and unambiguous 
approvals such as "yes", "go ahead", "apply it", or similar. Do NOT infer 
approval from context — if in doubt, ask. This applies to ALL situations 
including bug fixes, typo corrections, and error resolutions. Always take the 
approach of telling me what code changes you wish to make and let us go commit 
by commit unless I tell you otherwise.

## Pull Requests

### Comments
When a PR comment is shared, do NOT immediately propose or plan an 
implementation. Discuss it first — share your opinion, ask clarifying 
questions, push back if you disagree, or flag trade-offs. Only move toward 
implementation once there has been enough discussion and a clear decision has 
been made.

### Descriptions
Keep PR descriptions concise. Cover what was introduced, why it exists, and 
any notable side changes. No headers, no fluff.

## Git

When running git commands in a directory other than the current working 
directory, use `git -C <dir> <command>` rather than `cd <dir> && git <command>`. 
The latter triggers a Claude Code permission prompt (cd-then-git can execute 
untrusted hooks from the target directory), even for read-only commands.

## Skills

When I say `capture`, run the capture skill at ~/Documents/notes/skills/capture.md  
When I say `captureqa`, run the capture skill with the Q&A variant described there.
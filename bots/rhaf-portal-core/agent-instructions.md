## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.

# General Guidelines

- When moving files in a git repository, always use git mv if the file is versioned
- When sending a pull request you use the command: gh pr create --title "replace-me-with-a-title" --body "replace-me-with-the-body"
- You always fill the title and body with a short, concise and professional message.
- When creating issues you use the command: gh issue create --title "replace-me-with-a-title" --body "replace-me-with-the-body" --label "label1,label2"
- Issue labels are optional, but desirable
- If agents are available, use the most appropriate agent for the task.
- Always ask for a review from the adversarial-code-reviewer agent BEFORE sending the pull request.

# Writing Code

- Think before you write
- Don't create abstractions unnecessarily.
- Simplicity is important: focus on the minimum code required to achieve the result

# Iteracting with the world

You are careful not to disclose information about hostnames, address and internal infrastructure

# Skills and Specializations

- You always try to use the oss-helper when working on code
- When using the OSS Helper fix-issue workflow, open a pull request after completing the fix without waiting for a separate request.
- Prefer ripwire whenever possible and relevant across projects. Use the applicable ripwire skills for code navigation, analysis, reuse, and change checks.

---
name: user-env
description: User runs WSL (Ubuntu on Windows), working in /home/charleneshawn/ServiceSecurity/SEC_project
metadata:
  type: user
---

User works inside WSL (Ubuntu). The project path in WSL is `/home/charleneshawn/ServiceSecurity/SEC_project`. From Windows it's `\\wsl.localhost\Ubuntu\home\charleneshawn\ServiceSecurity\SEC_project`. Use PowerShell or the UNC path for file operations; use `wsl -e` prefix for shell commands if needed.

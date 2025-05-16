# DisableAccount.ps1

This PowerShell script disables a user account in both Active Directory and Microsoft 365. It handles verification, group cleanup, license removal, mailbox conversion, logging, and moves the user to a designated OU based on the current quarter.

## Features

- Prompts for a username and confirms details before continuing
- Removes the user from all on-prem AD groups (except Domain Users)
- Clears the `manager` attribute and reassigns direct reports
- Converts mailboxes to shared before license removal
- Removes Microsoft 365 licenses using Graph API
- Hides the user from the Global Address List (GAL)
- Moves the account to an OU named using the current year and quarter
- Saves logs to a specified path (default is `C:\temp`)

## Requirements

- PowerShell 5.1+
- RSAT tools (Active Directory and DNS PowerShell modules)
- Microsoft Graph PowerShell SDK
- Exchange Online PowerShell module
- Appropriate admin rights in both environments

## Example Use

```
Ticket number: 2024-193
Username: jdoe
Use the default log path (C:\temp)? y
```

This creates a log at:

```
C:\temp\2024-193_jdoe.log
```

## Author

- Ian Morley

## Contributor

- Aidan Payne
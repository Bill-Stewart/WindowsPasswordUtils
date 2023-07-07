# Windows Password Utilities

**ChangePassword** and **ResetPassword** are Windows console (command-line) utility programs that change and reset a user account's password, respectively. The following describes the difference between the terms _change_ and _reset_:

* _Change password_ means to update an account's password if you know the account's current password. A password change is typically initiated by a user to update their own password.

* _Reset password_ means to update an account's password without knowing the current password. You must have appropriate permissions. Usually a password reset is performed by a service desk, administrator, or other group that has been granted this permission.

## Copyright and Author

Copyright (C) 2023 by Bill Stewart (bstewart at iname.com)

## License

These programs covered by the GNU Public License (GPL). See the file `LICENSE` for details.

## Download

https://github.com/Bill-Stewart/WindowsPasswordUtils/

## Installation

There is no installation needed. Simply open a command prompt or PowerShell window and run the program you want by typing its name. If you are using PowerShell and want to run a program from the current directory, don't forget to prefix the program name with `.\` or `./`.

## ChangePassword

**ChangePassword** changes the password for a user account. You must know the current password.

The program will prompt for the information it needs:

    PS C:\Users\MyAdmin\Downloads\PasswordUtils\x86_64> .\ChangePassword
    Change password for current account (FABRIKAM\kdyer) [Y/N]?

Answer `Y` to this prompt to change the password for the current user. If you answer `N`, the program will prompt for an account name:

    Enter account name for password change [empty=quit]:

You can prefix the acount name with a domain name or computer name and the `\` character (e.g., `domain1\kdyer` or `computer2\ldyer`). If you omit a domain or computer name and `\` character, the program assumes the same domain or computer name as the current user.

The program will display the server to which it will connect to change the password, and then it will prompt for the current and new password. Passwords will not be displayed as they are typed.

    Password change server: \\FABRIKAMDC1

    Enter current password for FABRIKAM\kdyer:
    Enter new password for FABRIKAM\kdyer:
    Confirm new password for FABRIKAM\kdyer:

After entering the current and new passwords, the program will attempt the password change and will display a success or failure message.

> NOTE: Press `Ctrl+C` to abort the program at any time.

## ResetPassword

**ResetPassword** resets the password for a user account. You must have sufficient permissions to perform a password reset.

The program will prompt for the information it needs:

    PS C:\Users\MyAdmin\Downloads\PasswordUtils\x86_64> .\ResetPassword
    Enter account name for password reset [empty=quit]:

You can prefix the acount name with a domain name or computer name and the `\` character (e.g., `domain1\kdyer` or `computer2\ldyer`). If you omit a domain or computer name and `\` character, the program assumes the same domain or computer name as the current user.

The program will then display the account requesting the password reset (i.e., the current account), the server to which it will connect to reset the password, and then it will request whether to require a password change at next logon:

    Account requesting password reset: FABRIKAM\MyAdmin
    Password reset server: \\FABRIKAMDC1

    Require password change at next logon [Y/N]?

If you enter `Y` at this prompt, the system will require the user to change the password when logging on. If you enter `N`, the system will not require the user to change the password when logging on.

The program will then prompt for a new password for the account. Passwords are not displayed as they are typed.

    Enter new password for FABRIKAM\kdyer:
    Confirm new password for FABRIKAM\kdyer:

After entering the new password, the program will attempt the password reset and will display a success or failure message.

> NOTE: Press `Ctrl+C` to abort the program at any time.

## Technical and Security Details

*  **ChangePassword** uses the [**NetUserChangePassword**](https://learn.microsoft.com/en-us/windows/win32/api/lmaccess/nf-lmaccess-netuserchangepassword) API function to change a password.

* **ResetPassword** uses the [**NetUserSetInfo**](https://learn.microsoft.com/en-us/windows/win32/api/lmaccess/nf-lmaccess-netusersetinfo) API function to reset a password.

* According to the documentation, the **NetUserChangePassword** and **NetUserSetInfo** API functions do not control how the passwords are secured when sent over the network. Encryption of the passwords is handled by the Remote Procedure Call (RPC) mechanism supported by the network redirector that provides the network transport. Encryption is also controlled by the security mechanisms supported by the local computer and the security mechanisms supported by the remote network server. Passwords are not sent over the network in plain-text.

* The Windows API functions require the passwords in plain-text in memory temporarily in order to call the API functions. (Note that this is not any different from any other programs that use these API functions to change account passwords.) The programs overwrite the plain-text password strings in memory immediately after using them.

* If you don't specify a computer name or domain name in the account name (i.e., an account name without a _domainname_`\` or _computername_`\` prefix), the programs assume the same domain or computer name as the current logged on user. That is, if you are logged on with a domain account, the programs will assume the account is in the current domain; alternatively, if you are logged on with a local computer account, the programs will assume the account is a local account on the current computer.

* If you are logged on using a domain account or if you specify a computer name or domain name in the account name, the programs use the [**DsGetDCName**](https://learn.microsoft.com/en-us/windows/win32/api/dsgetdc/nf-dsgetdc-dsgetdcnamew) API function to attempt to get the name of a writable nearby domain controller. If the API function can't find a domain controller for the specified name, the programs will assume a remote computer name. For example, consider the following scenario:

    * You are logged onto the FABRIKAM domain
    * You run **ResetPassword** and enter `COMPUTER2\jdoe` for the account name (i.e., reset password for local account `jdoe` on `COMPUTER2`)

    In this example, **ResetPassword** will attempt to find a domain controller for the domain `COMPUTER2`. There will be a slight delay as the lookup runs. Since there is no domain with that name, the lookup will fail, and **ResetPassword** will use `COMPUTER2` as the remote computer name.

## File Hashes

| File                      | SHA256 Hash                                                      |
| ------------------------- | ---------------------------------------------------------------- |
| i386\ChangePassword.exe   | C24DCE33C4E05A5D55A27A07CA32CDFF0CF4CDE320872677D09E941CC362DBA2 |
| i386\ResetPassword.exe    | 5723CAC43E2B569BDAD2765309C7A1DA2ABFB5E2658BDE3E124F5E8EFD0166F4 |
| x86_64\ChangePassword.exe | 55BECFB3306B42F57EAE70C10B6ED1A9B5844BA7254B34D816F465071137F805 |
| x86_64\ResetPassword.exe  | B02271CD4FF902EE272B6AC7EC4963873E89FEE4B74D27D661DBF9A18BA27669 |

The file hashes are provided here to validate an untampered executable.

You can use PowerShell commands to validate a file's hash; e.g.:

    PS C:\> (Get-FileHash "C:\Tools\ResetPassword.exe" -Algorithm SHA256).Hash -eq "B02271CD4FF902EE272B6AC7EC4963873E89FEE4B74D27D661DBF9A18BA27669"
    True

If the hash doesn't match, the command's output will be `False` (i.e., the executable is from a bad download or has been tampered with).

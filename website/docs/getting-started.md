# Getting started

## Installation

Bash (Linux):
```bash
curl https://raw.githubusercontent.com/DudeBro249/docrunner/stable/installers/install-linux.sh | sudo bash
```

Bash (MacOS):

``` bash
curl https://raw.githubusercontent.com/DudeBro249/docrunner/stable/installers/install-mac.sh | sudo bash
```

Powershell (Windows):
```powershell
iwr -useb https://raw.githubusercontent.com/DudeBro249/docrunner/stable/installers/install-windows.ps1 | iex
```

If none of these methods work, you can also install the `docrunner` binary from
[the releases](https://github.com/DudeBro249/docrunner/releases).
Make sure to add it to PATH so you can access it from anywhere

## QuickStart

```shell
docrunner --help
```

## Python Example

```powershell
docrunner run --language python --markdown-path README.md --multi-file
```

- This command executes all python within `README.md` and does so by putting each snippet of python into a 
separate file, and running each file. If you don't want each snippet in a separate python file, just 
remove the --multi-file option.

## Updating

Updating docrunner is as simple as calling:
```powershell
docrunner self update
```

This will provide you with simple instructions on how to update docrunner

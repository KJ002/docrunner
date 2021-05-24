# Javascript

## Usage
```cmd
docrunner javascript [OPTIONS]
```

```
$ docrunner javascript --help
Usage: docrunner javascript [OPTIONS]

  The javascript language command

Options:
  --markdown-path TEXT            The path to the markdown file you would like
                                  to run code from

  --directory-path TEXT           The path to the directory where your
                                  javascript code should be stored and run You
                                  can install dependencies and store them in
                                  your package.json within this directory

  --startup-command TEXT          The command you would like to run in order
                                  to run  your code. Put the command in
                                  between quotes "gunicorn main:app"

  --multi-file / --no-multi-file  [default: False]
  --help                          Show this message and exit.
```

## What it does
Runs all javascript code in the markdown file you specify.
Makes use of all options in your `docrunner.toml` file, if it exists.

You can learn more about docrunner configuration [here](/docs/configuration)
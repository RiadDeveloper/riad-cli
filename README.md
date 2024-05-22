# ⚡ Riad
**Riad** is a modern extension builder for MIT App Inventor 2.

> **Note**: This readme is for an unreleased version of Riad. Head over to [main](https://github.com/RiadDeveloper/Riad-cli/tree/main) for current stable version.

## Features
* Faster builds
* Maven like dependency management
* Kotlin language support
* Support for AndroidManifest.xml

## Installation
> **Note**: Before installing Riad, make sure that you have JDK 8 or above installed.

### Windows
In PowerShell, run:
```ps1
iwr https://raw.githubusercontent.com/RiadDeveloper/Riad-cli/main/scripts/install/install.ps1 -useb | iex
```

### Linux and macOS
1. In the terminal, run:

    ```sh
    curl https://raw.githubusercontent.com/RiadDeveloper/Riad-cli/main/scripts/install/install.sh -fsSL | sh
    ```

2. Add `$HOME/.Riad/bin` to the `PATH` environment variable.

## Quick start
Now, that you've installed Riad, let's create a simple extension.

1. Open the terminal in the directory where you want to create your extension project.

2. Run `Riad create <NAME_OF_THE_EXTENSION>`.
This will show you some prompts.
    - `Package name`: This is the package name in which your extension class will be placed.
    - `Language`: The language in which you wish to write your extension. 
    This is just for the sake of sample code generation, you can later manually change the language as per your desire or even use both languages together.
    - `IDE`: Your favorite IDE or text editor.
    This is required to generate the file required by these IDEs to support features like code completion and syntax highlighting.
    You can of course use any other text editor as well, but it's very unlikely that it would work well with Riad projects even if it supports Java.

3. `cd` into the generated project directory and run `Riad build`.

4. That's it, the generated extension file (AIX) can be found in the `out` directory.

## Todo
- [ ] Core concepts of extension dev
- [ ] Faq
- [ ] Contributing
- [ ] Limitations
- [ ] List more features

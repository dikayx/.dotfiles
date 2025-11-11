# 🏡 Feel like home on any mac

## Get started

-   Install Xcode commandline tools

    ```bash
    xcode-select --install
    ```

-   Clone this repo & make scripts executable

    ```bash
    git clone https://github.com/dikayx/.dotfiles.git && chmod +x .dotfiles/*.sh
    ```

-   Run the script\*

    ```bash
    ./.dotfiles/install.sh -hn "My-MBP" -gn "John Doe" -ge "<your_mail>@example.com"
    ```

    > Note: I recommend using your GitHub email address and name here.

_\*) All arguments are optional. You can show a help message by providing the `--help` flag._

## One-click-setup

```bash
xcode-select --install \
  && git clone https://github.com/dikayx/.dotfiles.git \
  && chmod +x .dotfiles/*.sh \
  && ./.dotfiles/install.sh -hn "My-MBP"
```

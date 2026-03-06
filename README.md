# 🏡 Feel like home on any mac

## One-click-setup

```bash
curl -fsSL https://raw.githubusercontent.com/dikayx/.dotfiles/main/setup.sh | bash -s -- -hn "My-MBP" -gn "John Doe" -ge "<your_mail>@example.com"
```

---

<details>

<summary>Manual setup</summary>

## Manual setup

> The `setup.sh` script is only meant to be used with `curl` and `bash` as shown above. If you want to set up the dotfiles manually, you can follow the steps below.

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

    > **Note:** I recommend using your GitHub email address and name here.

_\*) All arguments are optional. You can show a help message by providing the `--help` flag._

</details>

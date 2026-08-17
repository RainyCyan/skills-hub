import argparse


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=1)
    args = parser.parse_args()
    print(f"training for {args.epochs} epoch")


if __name__ == "__main__":
    main()

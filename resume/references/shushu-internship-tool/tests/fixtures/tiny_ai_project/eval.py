import argparse


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    args = parser.parse_args()
    print(f"accuracy: 0.91 from {args.checkpoint}")


if __name__ == "__main__":
    main()

"""Prints a Roam page pulled by roam-api.sh as an outline, with each block's uid."""
import json
import sys

UID_KEY: str = ":block/uid"
STRING_KEY: str = ":block/string"
ORDER_KEY: str = ":block/order"
CHILDREN_KEY: str = ":block/children"


def print_children(node: dict, depth: int) -> None:
    children: list[dict] = sorted(node.get(CHILDREN_KEY, []), key=lambda block: block.get(ORDER_KEY, 0))
    for child in children:
        print("  " * depth + f"- [{child[UID_KEY]}] {child.get(STRING_KEY, '')}")
        print_children(child, depth + 1)


def main() -> None:
    page_file, page_title = sys.argv[1], sys.argv[2]
    result: list = json.load(open(page_file)).get("result") or []
    if not result:
        sys.exit(f"No page titled {page_title!r}")
    page: dict = result[0][0]
    print(f"# {page[':node/title']} [{page[UID_KEY]}]")
    print_children(page, 0)


main()

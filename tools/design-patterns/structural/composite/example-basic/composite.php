<?php
/*
Intent: treat part and whole uniformly.
- Must have: a common interface (Component) that both Leaf and Composite implement.
- Leaf: implements operations directly (no children).
- Composite: stores children (array of Component) and delegates/aggregates operations to them.
- Child management: add()/remove() live only on Composite (or on Component if you prefer full transparency).
- Client: talks to Component only-no instanceof checks or special-casing.
- Gotcha: keep traversal/iteration inside Composite; don’t leak structure.

ITERATOR vs COMPOSITE
- Composite defines the tree. Iterator defines how to walk that tree (DFS/BFS, filtered, etc.).
 */

interface Node
{
    public function render(): string;
}

final class Text implements Node
{
    public function __construct(private string $text)
    {
    }

    public function render(): string
    {
        return htmlspecialchars($this->text);
    }
}

final class Group implements Node
{
    /** @var Node[] */
    private array $children = [];

    public function add(Node $n): void
    {
        $this->children[] = $n;
    }

    public function render(): string
    {
        $out = "<div>";
        foreach ($this->children as $c) {
            $out .= $c->render();
        }
        return $out . "</div>";
    }
}

$root = new Group();
$root->add(new Text("Hello "));
$inner = new Group();
$inner->add(new Text("world!"));
$root->add($inner);

echo $root->render(); // <div>Hello <div>world!</div></div>
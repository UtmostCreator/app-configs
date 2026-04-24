<?php
/*
Delegation Pattern
------------------
Intent: An object passes (delegates) a task to a helper object
instead of doing it itself — but keeps the same interface.

Difference from Strategy:
- Strategy = interchangeable algorithms.
- Delegation = same responsibility, but helper *acts on behalf of* the main object.
*/

// Common interface
interface Printer {
    public function print(string $text): void;
}

// Real worker
final class RealPrinter implements Printer {
    public function print(string $text): void {
        echo "🖨️ Printing: {$text}\n";
    }
}

// Delegating class
final class Manager implements Printer {
    public function __construct(private Printer $printer) {}
    public function print(string $text): void {
        // Manager delegates to the RealPrinter
        $this->printer->print($text);
    }
}

// Client code
$mgr = new Manager(new RealPrinter());
$mgr->print("Monthly Report");
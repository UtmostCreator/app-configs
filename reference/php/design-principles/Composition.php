<?php
/*
Composition (OO principle: “favor composition over inheritance”)
- Intent: build behavior via has-a relationships; delegate work to contained objects.
- Must do: define small interfaces for roles (e.g., Engine), not concrete classes.
- Inject collaborators (constructor/setter) so they can be swapped (flexibility, testability).
- Delegate from the host to the collaborator ($this->engine->ignite()), don’t subclass just to reuse code.
- Use inheritance sparingly (stable, is-a hierarchies only); prefer composition when behavior varies.
- Smell to avoid: deep hierarchies, protected hacks, or switches to select behavior—extract to collaborators instead.
*/

interface Engine
{
    public function ignite(): string;
}

final class GasEngine implements Engine
{
    public function ignite(): string
    {
        return "Gas engine on";
    }
}

final class ElectricEngine implements Engine
{
    public function ignite(): string
    {
        return "Electric motor on";
    }
}

final class Car
{
    public function __construct(private Engine $engine)
    {
    }

    public function start(): string
    {
        return $this->engine->ignite();
    } // delegate
}

$car = new Car(new ElectricEngine());
echo $car->start(); // Electric motor on
<?php
/*
Strategy, and how this PHP example implements it:
- Why the name: From GoF—encapsulate interchangeable algorithms (“strategies”) behind a common interface and swap them at runtime.
- Roles here:
  • Strategy interface: RouteStrategy::buildRoute(float): string
  • Concrete strategies: CarStrategy, BikeStrategy, WalkStrategy, TransitStrategy
  • Context: Navigator holds a RouteStrategy
- Mechanics: Navigator uses composition + delegation—buildRoute($km) forwards to the injected strategy. Clients can switch behavior via setStrategy(...) without modifying Navigator.
- Benefits: Open/Closed (add new routing without touching Navigator), removes conditionals, isolates and unit-tests algorithms independently.
- When not: If variants are few/rarely change, a simple if/switch or a callable may suffice.
- Delegation: Yes—Navigator delegates the routing work to the strategy object; Strategy is inherently delegation-based.
*/

/** Strategy interface */
interface RouteStrategy
{
    public function buildRoute(float $km): string;
}

/** Concrete strategies */
final class CarStrategy implements RouteStrategy
{
    public function buildRoute(float $km): string
    {
        $mins = ($km / 40) * 60 + 5;
        return "CAR: ~" . (int)round($mins) . " min";
    }
}

final class BikeStrategy implements RouteStrategy
{
    public function buildRoute(float $km): string
    {
        $mins = ($km / 16) * 60 + 1;
        return "BIKE: ~" . (int)round($mins) . " min";
    }
}

final class WalkStrategy implements RouteStrategy
{
    public function buildRoute(float $km): string
    {
        $mins = ($km / 5) * 60;
        return "WALK: ~" . (int)round($mins) . " min";
    }
}

final class TransitStrategy implements RouteStrategy
{
    public function buildRoute(float $km): string
    {
        $mins = 8 + ($km / 20) * 60;
        return "TRANSIT: ~" . (int)round($mins) . " min";
    }
}

/** Context */
final class Navigator
{
    public function __construct(private RouteStrategy $strategy)
    {
    }

    public function setStrategy(RouteStrategy $s): void
    {
        $this->strategy = $s;
    }

    public function buildRoute(float $km): string
    {
        return $this->strategy->buildRoute($km);
    }
}

/** Demo */
$distance = 7; // km
$nav = new Navigator(new WalkStrategy());
echo $nav->buildRoute($distance), PHP_EOL;
$nav->setStrategy(new BikeStrategy());
echo $nav->buildRoute($distance), PHP_EOL;
$nav->setStrategy(new TransitStrategy());
echo $nav->buildRoute($distance), PHP_EOL;
$nav->setStrategy(new CarStrategy());
echo $nav->buildRoute($distance), PHP_EOL;


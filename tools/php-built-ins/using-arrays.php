<?php

$odd = [1,3,5,7];
$diff = [1,2,3,4,5];
$even = [2,4,6,8];
// 1 find if all numbers are even
$res = array_all($even, fn($el, $key) => $el % 2 === 0);
// var_dump($res);

// 2 find if any numbers are odd
$res = array_any($odd, fn($el, $key) => $el % 2 !==0);
// var_dump($res);

// 3 Convert all keys in ["Name"=>"John","AGE"=>25] to lowercase.
$data = ["Name"=>"John","AGE"=>25];
// v1
$keys = array_map('mb_strtolower', array_keys($data));
$values = array_values($data);
$res = array_combine($keys, $values);
// or v2
foreach($data as $key => $value) {
	$res[mb_strtolower($key)] = $value;
}
// v3 (best)
$res = array_change_key_case($data, CASE_LOWER);
// var_dump($res);
unset($res);

// 5 Split [1,2,3,4,5,6] into arrays of 2 elements each.
$data = [1,2,3,4,5,6];
$res = array_chunk($data, 2);
// var_dump($res);

// 6 Extract the "name" column from [["id"=>1,"name"=>"Tom"],["id"=>2,"name"=>"Anna"]].
$data = [
    ["id"=>1,"name"=>"Tom"],
    ["id"=>2,"name"=>"Anna"]
];
$res = array_column($data, 'name');
// var_dump($res);

// 7 Combine ["a","b","c"] with [10,20,30] as keys and values.
$data1 = ["a","b","c"];
$data2 = [10,20,30];
$res = array_combine($data1, $data2);
// var_dump($res);
unset($res);

// 8 Count how many times each value appears in ["a","b","a","c","a"].
$data = ["a","b","a","c","a"];
// v1
foreach($data as $val) {
	$res[$val] = isset($res[$val]) ? $res[$val] + 1 : 1;
}

// var_dump($res);
// v2
unset($res);
$res = array_count_values($data);
// var_dump($res);

// 9 Find which elements in [1,2,3,4] are not present in [3,4,5].
$data1 = [1,2,3,4];
$data2 = [3,4,5];
$res = array_diff($data1, $data2);
// var_dump($res);

// 10 Compare ['blue' => 1, 'red' => 2, 'green' => 3, 'purple' => 4] and ['green' => 5, 'yellow' => 7, 'cyan' => 8] and find differing key-value pairs.
$data1 = array('blue' => 1, 'red' => 2, 'green' => 3, 'purple' => 4);
$data2 = array('green' => 5, 'yellow' => 7, 'cyan' => 8);
$res = array_diff_key($data1, $data2);
// var_dump($res);

// 11 From ["a"=>1,"b"=>2,"c"=>3], remove all items whose keys exist in ["a"=>10,"d"=>20].
$data1 = ["a"=>1,"b"=>2,"c"=>3];
$data2 = ["a"=>10,"d"=>20];
$res = array_diff_key($data1, $data2);
// var_dump($res);

// 12 Compare two associative arrays by their keys using a custom function 
// that compares the *length* of each key. Return elements from the first array 
// whose key lengths are not present in the second array.
$data1 = ["a" => "cat", "bb" => "dog", "ccc" => "bet"];
$data2 = ["cc" => "cat", "b" => "lion", 'dddd' => 'mouse'];
$res = array_diff_ukey($data1, $data2, fn($a, $b) => strlen($a) <=> strlen($b));
// var_dump($res);

// 13 Compare keys of ["A"=>1,"b"=>2] and ["a"=>10,"B"=>20] ignoring letter case.
// Expected: Since "A" ≈ "a" and "b" ≈ "B", there are no unique keys in $data1.
// The result should be an empty array.
$data1 = ["A" => 1, "b" => 2];
$data2 = ["a" => 10, "B" => 20];
$res = array_diff_ukey($data1, $data2, fn($a, $b) => strtolower($a) <=> strtolower($b));
// var_dump($res);

// 14 Create an array of 4 "X" elements starting from index 3.
$data = 'X';
$res = array_fill(3, 4, $data);
// var_dump($res);

// 15 Create an array with keys ["id","name"] filled with null.
$data = ["id","name"];
// v1
$res = array_combine($data, array_fill(1, count($data), null));
// v2
$res = array_fill_keys($data, null);
// var_dump($res);

// 16 From [1,2,3,4,5,6], keep only even numbers.
$data = [1,2,3,4,5,6];
$res = array_filter($data, fn($el) => $el % 2 !== 0);
// var_dump($res);

// 17 Find the first value greater than 5 in [1,4,7,3].
$data = [1,4,7,3];
$res = array_find($data, fn($el) => $el > 5);
// var_dump($res);

// 18 Find the key of the first number greater than 5 in [2,6,3,9].
$data = [2,6,3,9];
$res = array_find_key($data, fn($el) => $el > 5);
// var_dump($res);

// 19 Return the first element of [10,20,30].
$data = [10,20,30];
reset($data);
// var_dump(current($data));
// var_dump($data[array_key_first($data)]); //7.4 build in

// 20 Swap keys and values in ["a"=>1,"b"=>2].
$data = ["a"=>1,"b"=>2];
// v1 slow
$res = array_combine(array_values($data), array_keys($data));
// v2 fast
$res = array_flip($data);
// var_dump($res);

// 21 Find common values between [1,2,3,4] and [3,4,5].
$data1 = [1,2,3,4];
$data2 = [3,4,5];
$res = array_intersect($data1, $data2);
// var_dump($res);

// 22 Compare two arrays by both key and value, returning common pairs.
$data1 = ["a"=>"red","b"=>"green","c"=>"blue"];
$data2 = ["a"=>"red","b"=>"yellow","c"=>"blue"];
$res = array_intersect_assoc($data1,$data2);
// var_dump($res);

// 23 Return values from ["a"=>1,"b"=>2,"c"=>3] whose keys exist in ["a"=>10,"c"=>20].
$data1 = ["a"=>1,"b"=>2,"c"=>3];
$data2 = ["a"=>10,"c"=>20];
$res = array_intersect_key($data1, $data2);
// var_dump($res);

// 24 Compare arrays by both key and value, using custom comparison for keys.
$data1 = ["a"=>1,"bb"=>2];
$data2 = ["cc"=>1,"b"=>2];
$res = array_intersect_uassoc(
    $data1,
    $data2,
    fn($key1, $key2) => strlen($key1) <=> strlen($key2)
);
// var_dump($res);

// 25 Return elements whose keys match by length between ["aa"=>1,"bbb"=>2] and ["cc"=>10,"dd"=>20].
$data1 = ["aa"=>1,"bbb"=>2];
$data2 = ["cc"=>10,"dd"=>20];
$res = array_intersect_ukey(
    $data1,
    $data2,
    fn($key1, $key2) => strlen($key1) <=> strlen($key2)
);
// var_dump($res);

// 26 Determine if [10,20,30] is a numerically indexed list.
$data = [10,20,30];
$res = array_is_list($data); // not works with edge cases e.g. if start index is 1 or greater
$res = array_all($data, fn($el, $key) => is_numeric($key));
// var_dump($res);

// 27 Check if "age" exists in ["name"=>"Alex","age"=>30].
$data = ["name"=>"Alex","age"=>30];
// var_dump(isset($data['age']));

// 28 Get the first key from ["x"=>10,"y"=>20].
$data = ["x"=>10,"y"=>20];
// var_dump(array_key_first($data));

// 29 Get the last key from ["x"=>10,"y"=>20].
$data = ["x"=>10,"y"=>20];
// var_dump(array_key_last($data));

// 30 Return all keys from ["a"=>1,"b"=>2].
$data = ["a"=>1,"b"=>2];
// var_dump(array_keys($data));

// 31 Return the last element from [10,20,30].
$data = [10,20,30];
// var_dump(end($data));

// 32 Apply squaring to every element in [1,2,3,4].
$data = [1,2,3,4];
// var_dump(array_map(fn($el) => $el ** 2, $data));

// 33 Combine [1,2] and [3,4] into one array.
$data1 = [1,2];
$data2 = [3,4];
// var_dump(array_combine($data1, $data2));

// 34 Merge [ "a"=>1, "b"=>["x"] ] and [ "b"=>["y"] ] so nested arrays merge.
$data1 = ["a"=>1,"b"=>["x"]];
$data2 = ["b"=>["y"]];
// var_dump(array_merge($data1, $data2));

// 35 Sort two related arrays ($names and $ages) together by ages.
// When ages are sorted ascending, the names must stay linked
// to their corresponding age.
$names = ["John", "Anna",  "A", "Z"];
$ages = [30, 25, 55, 11];
$res = array_combine($names, $ages);
uasort($res, fn($v1, $v2) => $v1 <=> $v2);
// C based, faster and keeps it diret as asked in task
array_multisort($ages, SORT_ASC, $names);
// var_dump($res);
// var_dump($names, $ages);


// 36 Extend [1,2,3] to 5 elements by adding zeros.
$data = [1,2,3];
$res = array_pad($data, count($data) + 2, 0);
// var_dump($res);

// 37 Remove and return the last value from [1,2,3].
$data = [1,2,3];
// var_dump(array_pop($data));

// 38 Multiply all numbers in [2,3,4].
$data = [2,3,4];
// var_dump(array_map(fn($el) => $el * 2, $data));

// 39 Add "pear" and "plum" to ["apple","banana"].
$data = ["apple","banana"];
array_push($data, "pear");
array_push($data, "plum");
// var_dump($data);

// 40 Pick one random key from [10,20,30].
$data = [10,20,30];
$keys = array_keys($data);
$key = rand(min($keys), max($keys));
$key = array_rand($data);
// var_dump($key);

// 41 Sum [1,2,3,4] using callback accumulator.
$data = [1,2,3,4];
// var_dump(array_reduce($data, fn($carry, $item) => $carry += $item));

// 42 Replace values in ["a"=>1,"b"=>2] using ["a"=>3].
$data1 = ["a"=>1,"b"=>2];
$data2 = ["a"=>3];
// var_dump(array_replace($data1, $data2));

// 43 Merge nested arrays replacing subkeys recursively. Combine two multi-dimensional (nested) associative arrays so that any matching keys inside sub-arrays are overwritten by the second array, while all non-matching keys are kept.
$data1 = ["a"=>["x"=>1,"y"=>2]];
$data2 = ["a"=>["y"=>5,"z"=>9]];
$res = array_replace_recursive($data1, $data2);
// var_dump($res);
// var_dump($res);

// 44 Reverse [1,2,3,4].
$data = [1,2,3,4];
// var_dump(array_reverse($data));

// 45 Find the key of "green" in ["a"=>"red","b"=>"green"].
$data = ["a"=>"red","b"=>"green"];
// var_dump(array_find_key($data, fn($el) => $el === 'green'));

// 46 Remove and return the first value from [10,20,30].
$data = [10,20,30];
// var_dump(array_shift($data), $data);

// 47 Get [2,3] from [1,2,3,4].
$data = [1,2,3,4];
// var_dump(array_slice($data, 1, 2));

// 48 Remove 2 elements from index 1 in [1,2,3,4,5].
$data = [1,2,3,4,5];
// var_dump(array_splice($data, 1, 2));

// 49 Add all numbers in [5,10,15].
$data = [5,10,15];
// var_dump(array_reduce($data, fn($carry, $item) => $carry += $item));
// var_dump(array_sum($data));

// 50 Compare two arrays by custom value length and return the difference.
$data1 = ["Laptop", "Smartphone", "Monitor"];
$data2 = ["laptop", "Headphones"];

$res = array_udiff(
    $data1,
    $data2,
    fn($a, $b) => strcasecmp($a, $b)   // case-insensitive comparison
);

// var_dump($res);

// 51 Same as above but include key comparison.
$data1 = ["a"=>"cat","b"=>"lion"];
$data2 = ["x"=>"dog","y"=>"elephant"];
// var_dump($res);

// 52 Compare both key and value using user functions.
$data1 = ["a"=>"cat"];
$data2 = ["b"=>"dog"];
// var_dump($res);

// 53 Find intersection of two arrays using custom comparison.
$data1 = ["cat","lion"];
$data2 = ["lion","tiger"];
// var_dump($res);

// 54 Same as above but associative.
$data1 = [
    "PC001" => "Laptop",
    "PC002" => "Desktop",
    "PC003" => "Monitor"
];

$data2 = [
    "pc001" => "laptop",     // same item, different case
    "PC004" => "Headphones"
];

$res = array_udiff_uassoc(
    $data1,
    $data2,
    fn($a, $b) => strcasecmp($a, $b),  // compare values ignoring case
    fn($k1, $k2) => strcasecmp($k1, $k2) // compare keys ignoring case
);

// var_dump($res);

// 55 Compare both key and value using user-defined for each.
$data1 = ["a" => "cat"];
$data2 = ["b" => "dog"];

$res = array_udiff_uassoc(
    $data1,
    $data2,
    fn($a, $b) => strlen($a) <=> strlen($b),  // compare values by length
    fn($k1, $k2) => strcmp($k1, $k2)          // compare keys alphabetically
);

// var_dump($res);

// 56 Remove duplicates from [1,1,2,3,3].
$data = [1,1,2,3,3];
// var_dump(array_unique($data));
// var_dump(array_keys(array_flip($data)));

// 57 Add "x" to the beginning of [2,3].
$data = [2,3];
array_unshift($data, 'x');
// var_dump($data);

// 58 Extract all values from ["a"=>10,"b"=>20].
$data = ["a"=>10,"b"=>20];
// var_dump(array_values($data), array_keys($data));

// 59 Append "!" to each word in ["Hi","There"].
$data = ["Hi","There"];
// var_dump(array_map(fn($el) => $el = '!'. $el, $data));


$a = ["user" => ["name" => "John", "age" => 30]];
$b = ["user" => ["age" => 40, "city" => "Edinburgh"]];
// var_dump(array_merge_recursive($a, $b)); // "age"  => [30, 40], 
// var_dump(array_replace_recursive($a, $b)); // "age"  => 40,   

// 60 Apply strtoupper to all elements in ["a"=>["x"=>"hi"]].
$data = ["a"=>["x"=>"hi"]];
array_walk_recursive($data, fn(&$val) => $val = strtoupper($val));
// var_dump($data);

$data = ["a", "b", "c"];
array_walk($data, fn (&$v) => $v = strtoupper($v));  // modifies in place
// $data = ["A","B","C"]

$data = ["a", "b", "c"];
$res = array_map('strtoupper', $data);               // returns new array
// $res = ["A","B","C"]; $data unchanged


// 61 Sort ["a"=>2,"b"=>5,"c"=>1] by value descending, keep keys.
$data = ["a"=>2,"b"=>5,"c"=>1];
arsort($data);
// var_dump($data);

// 62 Sort same array ascending by value, keep keys.
$data = ["a"=>2,"b"=>5,"c"=>1];
asort($data);
// var_dump($data);

// 63 Create an array using existing variables $a=1,$b=2.
$a=1; $b=2;
// var_dump([$a, $b]);

// 64 Count number of items in [10,20,30, 'a'].
$data = [10, 20, 30, 'a'];
// v1
$res = array_reduce($data, fn($carry, $v) => $carry + (is_numeric($v) ? 1 : 0), 0);
// v2 faster, simpler
$res = count(array_filter($data, 'is_numeric'));
// var_dump($res);

// 65 Return the current element of [10,20,30].
$data = [10,20,30];
// var_dump(current($data));

// 66 Move pointer to last element and return it.
$data = [10,20,30];
// var_dump(end($data));

// 67 Create variables from ["name"=>"Alex","age"=>30].
$data = ["name"=>"Alex","age"=>30];
extract($data);
// var_dump($name, $age);
// var_dump($res);

$data = ["Alex", 30];
extract($data); // does not produce meaninful output
// var_dump($_1); // wont work

// 68 Check if 20 exists in [10,20,30].
$data = [10,20,30];
// var_dump(in_array(20, $data));

// 69 Return the current key of ["a"=>1,"b"=>2].
$data1 = ["a" => 1, "b" => 2];
$data2 = [10,20,30];
$data3 = ["a" => ["x" => 1, "y" => 2], "b" => [3, 4]];
// var_dump(key($data));

function is_list_recursive(array $arr): bool {
    $expected = 0;
    foreach ($arr as $key => $value) {
        // keys must be sequential integers
        if (!is_int($key) || $key !== $expected++) {
            return false;
        }
        // recurse into nested arrays
        if (is_array($value) && !is_list_recursive($value)) {
            return false;
        }
    }
    return true;
}
// var_dump(is_list_recursive($data3));

// 70 Same as task 27 using alias.
$data = ["name"=>"Alex","age"=>30];
$res = array_flip($data);
// var_dump($res);

// 71 Sort associative array by keys descending.
$data = ["a"=>1,"b"=>2,"c"=>3];
krsort($data);
// var_dump($data);

// 72 Sort associative array by keys ascending.
$data = ["a"=>1,"b"=>2,"c"=>3];
ksort($data);
// var_dump($data);

// 73 Assign [1,2,3] into $a,$b,$c.
$data = [1, 2, 3];
[$a, $b, $c] = $data;
list($a,$b,$c) = $data;
// var_dump($a, $b, $c);

// 74 Sort ["file10","file2","File1"] naturally, ignoring case.
$data = ["file10","file2","File1"];
natcasesort($data);
// var_dump($data);

// 75 Sort ["img12","img2","img1"] in natural order.
$data = ["img12","img2","img1"];
natsort($data);
// var_dump($data);

// 76 Move pointer one step forward and show value.
$data = [10,20,30];
// var_dump(next($data));

// 77 Get current element (alias).
$data = [10,20,30];
// var_dump(pos($data)); // 10 pos is an alternative to current

// 78 Move pointer one step back.
$data = [10,20,30];

// var_dump(prev($data)); // false


// 79 Create array with numbers 1 to 5.
$data = null;
// var_dump(range(0,5));

// 80 Reset pointer to first element.
$data = [10, 20, 30];
// var_dump(reset($data));

// 81 Sort [1,9,3,7,5] descending without keeping keys.
$data = [1,9,3,7,5];
rsort($data);
// var_dump($data);

// 82 Randomly reorder [1,2,3,4].
$data = [1,2,3,4];
// var_dump(shuffle($data));

// 83 Count elements in [10,20,30] (alias).
$data = [10,20,30];
// var_dump(sizeof($data));

// 84 Sort [9,3,5,1,7] ascending without keeping keys.
$data = [9,3,5,1,7];
sort($data);
// var_dump($data);

// 85 Sort array by value using custom user function.
$data = ["apple","pear","banana"];
usort($data, fn($a, $b) => strlen($b) <=> strlen($a));
// var_dump($data);

// 86 Sort array by key using custom user function.
$data = ["a"=>5,"bb"=>1,"ccc"=>3];
uksort($data, fn($a, $b) => strlen($b) <=> strlen($a));
// var_dump($data);

// 87 Sort indexed array using custom user comparison.
$data = [5, 2, 8, 1];

usort($data, fn($a, $b) => $a <=> $b); // ascending
// var_dump($data);

// depricated
// 88 Iterate over [1,2,3] and return key-value pairs one by one (legacy).
$data = [1,2,3];

// while ($res = each($data)) {
//     var_dump($res);
// }
// var_dump($res);


// 🔹 89 Multiply all values in [2,3,4].
$data = [2,3,4];
$res = array_product($data);
// var_dump($res);

// 🔹 90 Find the key of value 20 in ["a"=>10,"b"=>20,"c"=>30].
$data = ["a"=>10,"b"=>20,"c"=>30, 20 => 222, 20 => 'two zero'];
$res = array_search(20, $data);
// var_dump($res);

// 🔹 91 Compare two arrays by both keys and values (standard diff).
$data1 = ["a"=>1,"b"=>2,"c"=>3];
$data2 = ["a"=>1,"b"=>4,"c"=>3];
$res = array_diff_assoc($data1, $data2);
// var_dump($res); // ["b"]=>int(2)

// 🔹 92 Compare arrays by value with user-defined comparison.
$data1 = ["apple","pear","banana"];
$data2 = ["APPLE","banana","kiwi"];
$res = array_udiff_assoc($data1, $data2, fn($a,$b)=>strcasecmp($a,$b));
// var_dump($res); // [[1]=> string(4) "pear" [2]=> string(6) "banana"]

// 🔹 93 Find intersection of two arrays using user-defined comparison.
$data1 = ["apple","pear","banana"];
$data2 = ["APPLE","plum","BANANA"];
$res = array_uintersect($data1, $data2, fn($a,$b)=>strcasecmp($a,$b));
// var_dump($res); // array(2) { [0]=> string(5) "apple" [2]=> string(6) "banana" }

// 🔹 94 Find intersection by key and value using user-defined comparison.
$data1 = ["a"=>"apple","b"=>"pear"];
$data2 = ["a"=>"APPLE","c"=>"PEAR"];
$res = array_uintersect_assoc($data1, $data2, fn($a,$b)=>strcasecmp($a,$b));
// var_dump($res); // array(2) { [0]=> string(5) "apple" [2]=> string(6) "banana" }

// 🔹 95 Compare both key and value using user-defined for each.
$data1 = ["A"=>"apple","B"=>"pear"];
$data2 = ["a"=>"APPLE","c"=>"pear"];
$res = array_uintersect_uassoc(
    $data1,
    $data2,
    fn($a,$b)=>strcasecmp($a,$b),
    fn($k1,$k2)=>strcasecmp($k1,$k2)
);
// var_dump($res); // array(1) { ["A"]=> string(5) "apple" }

// 🔹 96 Create array from variables $x=5, $y=10.
$x=5; $y=10;
$res = compact('x','y');
var_dump($res); // array(2) { ["x"]=> int(5) ["y"]=> int(10) }

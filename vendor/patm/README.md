# PATM: PATtern Matcher for Ruby

[![Build Status](https://travis-ci.org/todesking/patm.svg?branch=master)](https://travis-ci.org/todesking/patm)
[![Code Climate](https://codeclimate.com/github/todesking/patm.png)](https://codeclimate.com/github/todesking/patm)

PATM is extremely faster pattern match library.

Features: Match value/classes, Capture, Array/Hash decomposition.

## Usage

```ruby
require 'patm'
```

```ruby
# With DSL
class A
  extend ::Patm::DSL

  define_matcher :match1 do|r|
    p = Patm
    r.on [:x, p._1, p._2] do|m|
      [m._1, m._2]
    end
  end

  define_matcher :match2 do|r|
    r.on [:a, Patm._xs & Patm._1] do|m, _self|
      _self.match1(m._1)
    end
    # ...
    r.else do
      nil
    end
  end
end

A.new.match1([:x, 1, 2])
# => [1, 2]
```

```ruby
# With case(simple but slow)
def match(obj)
  p = Patm
  _xs = Patm._xs
  case obj
  when m = Patm.match([:x, p._1, p._2])
    [m._2, m._1]
  when m = Patm.match([1, _xs&p._1])
    m._1
  end
end

match([1, 2, 3])
# => [2, 3]

match([:x, :y, :z])
# => [:z, :y]

match([])
# => nil
```

```ruby
# With pre-built Rule
rule = Patm::Rule.new do|r|
  p = Patm
  _xs = Patm._xs
  r.on [:x, p._1, p._2] do|m|
    [m._2, m._1]
  end
  r.on [1, _xs&p._1] do|m|
    m._1
  end
end

rule.apply([1,2,3])
# => [2, 3]

rule.apply([:x, :y, :z])
# => [:z, :y]

rule.apply([])
# => nil
```

## DSL

```ruby
class PatternMatcher
  extend Patm::DSL

  define_matcher(:match) do|r| # r is instance of Patm::Rule
    # r.on( PATTERN ) {|match, _self|
    #   First argument is instance of Patm::Match. Use it to access captured value.
    #   ex. m._1, m._2, ..., m[capture_name]
    #
    #   Second argument is instance of the class. Use it to access other methods.
    #   ex. _self.other_method
    # }
    #
    # r.else {|value, _self|
    #   First argument is the value. Second is instance of the class.
    # }
  end
end

matcher = PatternMatcher.new

matcher.match(1)
```

## Patterns

### Value

Value patterns such as `1, :x, String, ...` matches if `pattern === target_value` is true.

### Struct

```ruby
A = Struct.new(:x, :y)

# ...
define_matcher :match_struct do|r|
  # use Patm[struct_class].( ... ) for match struct
  # argument is a Hash(member_name => pattern) or patterns that correspond struct members.
  r.on Patm[A].(x: 1, y: Patm._1) {|m| m._1 }
  r.on Patm[A].(2, Patm._1) {|m| m._1 }
end
```

### Array

`[1, 2, _any]` matches `[1, 2, 3]`, `[1, 2, :x]`, etc.

`[1, 2, _xs]` matches `[1, 2]`, `[1, 2, 3]`, `[1, 2, 3, 4]`, etc.

`[1, _xs, 2]` matches `[1, 2]`, `[1, 10, 2]`, etc.

Note: More than one `_xs` in same array is invalid.

### Hash

`{a: 1}` matches `{a: 1}`, `{a: 1, b: 2}`, etc.

`{a: 1, Patm.exact => true}` matches only `{a: 1}`.

`{a: 1, b: Patm.opt(2)}` matches `{a: 1}`, `{a: 1, b: 2}`.

### Capture

`_1`, `_2`, etc matches any value, and capture the value as correspond match group.

`Pattern#[capture_name]` also used for capture.`Patm._any[:foo]` capture any value as `foo`.

Captured values are accessible through `Match#_1, _2, ...` and `Match#[capture_name]`

### Compose

`_1&[_any, _any]` matches any two element array, and capture the array as _1.
`Patm.or(1, 2)` matches 1 or 2.


## Performance

see [benchmark code](./benchmark/comparison.rb) for details

Machine: MacBook Air(Late 2010) C2D 1.8GHz, OS X 10.9.2

```
RUBY_VERSION: 2.1.2 p95

Benchmark: Empty(x10000)
                    user     system      total        real
manual          0.010000   0.000000   0.010000 (  0.012252)
patm            0.060000   0.000000   0.060000 (  0.057050)
pattern_match   1.710000   0.010000   1.720000 (  1.765749)

Benchmark: SimpleConst(x10000)
                    user     system      total        real
manual          0.020000   0.000000   0.020000 (  0.018274)
patm            0.060000   0.000000   0.060000 (  0.075068)
patm_case       0.160000   0.000000   0.160000 (  0.161002)
pattern_match   1.960000   0.020000   1.980000 (  2.007936)

Benchmark: ArrayDecomposition(x10000)
                    user     system      total        real
manual          0.050000   0.000000   0.050000 (  0.047948)
patm            0.250000   0.000000   0.250000 (  0.254039)
patm_case       1.710000   0.000000   1.710000 (  1.765656)
pattern_match  12.890000   0.060000  12.950000 ( 13.343334)

Benchmark: VarArray(x10000)
                    user     system      total        real
manual          0.050000   0.000000   0.050000 (  0.052425)
patm            0.210000   0.000000   0.210000 (  0.223190)
patm_case       1.440000   0.000000   1.440000 (  1.587535)
pattern_match  10.050000   0.070000  10.120000 ( 10.898683)
```


## Changes

### 3.1.0

- Struct matcher

### 3.0.0

- If given value can't match any pattern and no `else`, `Patm::NoMatchError` raised(Instead of return nil).
- RuleCache is now obsoleted. Use DSL.
- More optimized compiler

### 2.0.1

- Bugfix: About pattern `Patm._1 & Array`.
- Bugfix: Compiler bug fix.

### 2.0.0

- Named capture
- Patm::GROUPS is obsolete. Use `pattern[number_or_name]` or `Patm._1, _2, ...` instead.
- More optimize for compiled pattern.
- Hash patterns

### 1.0.0

- DSL
- Compile is enabled by default
- Change interface

### 0.1.0

- Faster matching with pattern compilation
- Fix StackOverflow bug for `[Patm.or()]`

### 0.0.1

- Initial release


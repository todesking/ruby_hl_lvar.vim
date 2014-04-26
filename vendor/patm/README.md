# PATM: PATtern Matcher for Ruby

## Usage

```ruby
require 'patm'
```

```ruby
# With case(simple but slow)
def match(obj)
  p = Patm
  _xs = Patm::ARRAY_REST
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
  _xs = Patm::ARRAY_REST
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

```ruby
# With cached rules
class A
  def initialize
    @rules = Patm::RuleCache.new
  end

  def match1(obj)
    @rules.match(:match1, obj) do|r|
      p = Patm
      r.on [:x, p._1, p._2] do|m|
        [m._1, m._2]
      end
    end
  end

  def match2(obj)
    @rules.match(:match2, obj) do|r|
      # ...
    end
  end
end
 ```


## Changes

### 0.1.0

- Faster matching with pattern compilation
- Fix StackOverflow bug for `[Patm.or()]`

### 0.0.1

- Initial release

